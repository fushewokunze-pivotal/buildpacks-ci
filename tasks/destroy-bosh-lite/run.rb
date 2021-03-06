#!/usr/bin/env ruby

require_relative '../../lib/bosh-lite-manager.rb'

iaas = ENV.fetch('IAAS')
deployment_id = ENV.fetch('DEPLOYMENT_NAME')
domain_name = ENV.fetch('BOSH_LITE_DOMAIN_NAME')
bosh_private_key = ENV.fetch('BOSH_PRIVATE_KEY')

bosh_lite_url = "https://#{deployment_id}.#{domain_name}"

if iaas == 'azure' || iaas == 'gcp'
  bosh_lite_deployment_name = ENV.fetch("#{iaas.upcase}_BOSH_LITE_NAME")
  bosh_director_user = ENV.fetch("#{iaas.upcase}_BOSH_DIRECTOR_USER")
  bosh_director_password = ENV.fetch("#{iaas.upcase}_BOSH_DIRECTOR_PASSWORD")
  bosh_director_target = "10.0.0.6"
elsif iaas == 'aws'
  bosh_lite_deployment_name = bosh_director_user = bosh_director_password = bosh_director_target = nil
else
  puts "Please specify IAAS=(aws|azure|gcp)"
  exit 1
end

Dir.chdir ('deployments-buildpacks') do
  rubygem_mirror = ENV.fetch('RUBYGEM_MIRROR')
  exit 1 unless system "bundle config mirror.https://rubygems.org #{rubygem_mirror}"
  num_cores = `nproc`.strip
  exit 1 unless system "bundle install --jobs=#{num_cores} --retry 5"
end

deployment_dir = File.join(Dir.pwd,'deployments-buildpacks', 'deployments', deployment_id)

manager = BoshLiteManager.new(iaas: iaas,
                               deployment_dir: deployment_dir,
                               deployment_id: deployment_id,
                               bosh_lite_deployment_name: bosh_lite_deployment_name,
                               bosh_lite_url: bosh_lite_url,
                               bosh_lite_user: nil,
                               bosh_lite_password: nil,
                               bosh_director_user: bosh_director_user,
                               bosh_director_password: bosh_director_password,
                               bosh_director_target: bosh_director_target,
                               bosh_private_key: bosh_private_key,
                               credentials_struct: nil
                              )

manager.destroy
