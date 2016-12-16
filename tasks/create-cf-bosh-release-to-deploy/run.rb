#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/cf-release-common"

release_names.each do |language|
  blobs = YAML.load File.read('cf-release/config/blobs.yml')
  key = find_buildpack_key blobs, language
  src = Dir["#{language}-buildpack-github-release/*.zip"].first
  next unless src
  dst = File.join('cf-release', 'blobs', key)
  FileUtils.mkdir_p File.dirname(dst)
  FileUtils.mv src, dst
end

replacement_function = <<-FUNCTION
running_in_container() {
  true
}
FUNCTION

Dir.chdir 'cf-release' do
  files_to_edit = Dir["**/*.sh"].select do |file|
    File.read(file).include? 'running_in_container()'
  end

  files_to_edit.each do |file|
    contents=File.read(file)

    contents.gsub!(/running_in_container\(\)\s+{.*}/m, replacement_function )
    File.write(file, contents)
    puts "Replaced running_in_container() in #{file}"
  end

  system(%(bundle && bosh --parallel 10 sync blobs && bosh create release --force --with-tarball --name cf --version 212.0.#{Time.now.to_i})) || raise('cannot create cf-release')
end

system('rsync -a cf-release/ cf-release-artifacts') || raise('cannot rsync directories')
