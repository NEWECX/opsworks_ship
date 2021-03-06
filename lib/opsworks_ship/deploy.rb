require 'json'

require "opsworks_ship/aws_data_helper"
include AwsDataHelper

require "opsworks_ship/aws_deployment_helper"
include AwsDeploymentHelper

require "opsworks_ship/hipchat_helper"
include HipchatHelper

module OpsworksShip
  class Deploy
    def initialize(stack_name:, revision:, app_type:, app_layer_name_regex:, hipchat_auth_token: nil, hipchat_room_id: nil)
      @stack_name = stack_name
      raise "Invalid stack name, valid stacks are: #{all_stack_names}" unless all_stack_names.any?{|available_name| available_name == stack_name}

      @revision = revision

      @app_type = app_type
      raise "Invalid app type #{@app_type}" unless opsworks_app_types.include?(@app_type)

      @app_layer_name_regex = app_layer_name_regex

      @hipchat_auth_token = hipchat_auth_token
      @hipchat_room_id = hipchat_room_id
      raise "Must supply both or neither hipchat params" if [@hipchat_auth_token, @hipchat_room_id].compact.size == 1
    end

    def deploy
      start_time = Time.now

      puts "\n-------------------------------------"
      puts "Deployment started"
      puts "Revision: #{@revision}"
      puts "Stack: #{@stack_name}"
      puts "-------------------------------------\n\n"

      set_revision_in_opsworks_app

      deployment_id = start_deployment({ :Name => "deploy" }.to_json.gsub('"', "\\\""))
      final_status = monitor_deployment(deployment_id)

      if final_status.downcase =~ /successful/
        msg = "#{@app_type} deployment successful! Layers #{@app_layer_name_regex} now on #{@revision} deployed to #{@stack_name} by #{deployed_by}"
        post_deployment_to_hipchat(msg)
      else
        raise "Deployment failed, status: #{final_status}"
      end

      run_time_seconds = Time.now.to_i - start_time.to_i
      timestamped_puts "Deployment time #{run_time_seconds / 60}:%02i" % (run_time_seconds % 60)
    end

    def set_revision_in_opsworks_app
      timestamped_puts "Setting revision #{@revision}"
      cmd = "aws opsworks update-app --app-id #{app_id(stack_id)} --app-source Revision=#{@revision}"
      timestamped_puts "#{cmd}"
      `#{cmd}`
    end

  end
end
