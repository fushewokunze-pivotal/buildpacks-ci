# encoding: utf-8

require 'json'
require 'yaml'
require_relative './git-client'

class StateOfBoshLites

  attr_reader :state_of_environments, :environments

  def initialize
    @state_of_environments = []
    @gcp_environment_names = %w(edge-1.buildpacks-gcp.ci
                                edge-2.buildpacks-gcp.ci
                                lts-1.buildpacks-gcp.ci
                                lts-2.buildpacks-gcp.ci)

    @aws_environment_names = %w(edge-1.buildpacks.ci
                               edge-2.buildpacks.ci
                               lts-1.buildpacks.ci
                               lts-2.buildpacks.ci)

    @environments = {'aws' => @aws_environment_names,
                     'gcp' => @gcp_environment_names}
  end

  def get_environment_status(environment, iaas)
    type = environment.split('-').first

    resource_type = "cf-#{type}#{iaas=='aws' ? '' : '-'+ iaas}-environments"

    if File.exist?("#{resource_type}/claimed/#{environment}")
      claimed = true
      regex = / (.*) claiming: #{environment}/
    elsif File.exist?("#{resource_type}/unclaimed/#{environment}")
      claimed = false
      regex = / (.*) unclaiming: #{environment}/
    else
      return nil
    end

    #find which job claimed / unclaimed the environment
    recent_commits = GitClient.get_list_of_one_line_commits(Dir.pwd, 500)

    most_recent_commit = recent_commits.select do |commit|
      commit.match regex
    end.first

    concourse_job = nil
    if most_recent_commit
      most_recent_commit.match regex
      concourse_job = $1
    end

    {'claimed' => claimed, 'job' => concourse_job}
  end

  def display_state(output_type)
    unless %w(json text yaml).include? output_type
      raise "Invalid output type: #{output_type}"
    end

    puts "\n"
    if output_type == 'json'
      puts state_of_environments.to_json
    elsif output_type == 'yaml'
      puts state_of_environments.to_yaml
    elsif output_type == 'text'
      state_of_environments.each do |env|
        if env['status'].nil?
          # escape sequence colors yellow
          puts "#{env['name']}: \n  \e[33mDoes not currently exist in pool\e[0m"
        else
          if env['status']['claimed']
            # escape sequence colors red
            env_status = "\e[31mclaimed\e[0m"
          else
            # colors green
            env_status = "\e[32munclaimed\e[0m"
          end
          pipeline = env['status']['job'].split()[0].split('/')[0]
          job = env['status']['job'].split()[0].split('/')[1]
          build_number = env['status']['job'].split()[2]
          puts "#{env['name']}: \n  #{env_status} by job: #{env['status']['job']} \n\t https://buildpacks.ci.cf-app.com/teams/main/pipelines/#{pipeline}/jobs/#{job}/builds/#{build_number}\n"
        end
      end
    end
  end

  def get_states!(resource_pools_dir: nil, git_pull: true)
    raise "resource_pools_dir is required" if resource_pools_dir.nil?

    Dir.chdir(resource_pools_dir) do
      GitClient.pull_current_branch if git_pull
      get_all_environment_statuses
    end
  end

  def bosh_lite_in_pool?(deployment_id)
    bosh_lite_env = state_of_environments.find {|env| deployment_id == env['name'] }
    !bosh_lite_env['status'].nil?
  end

  private

  def get_all_environment_statuses
    environments.each do |iaas, environment_names|
      environment_names.each do |env|
        state_of_environments.push({'name' => env, 'status' => get_environment_status(env, iaas)})
      end
    end
  end
end
