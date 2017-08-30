require 'json'

module OpsworksShip
  class Deploy
    def initialize(stack_name, revision, app_type, app_layer_name_regex, hipchat_auth_token = nil, hipchat_room_id = nil)
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

    def syntax
      puts "Arguments: #{method(:initialize).parameters.map{|p| "#{p.last} (#{p.first})"}.join(' ')}"
      puts "\n"
      puts "Valid stacks: #{all_stack_names}}"
    end

    def deploy
      start_time = Time.now

      puts "\n-------------------------------------"
      puts "Deployment started"
      puts "Revision: #{@revision}"
      puts "Stack: #{@stack_name}"
      puts "-------------------------------------\n\n"

      set_revision_in_opsworks_app

      deployment_id = start_deployment
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

    def all_stack_names
      @all_stack_names ||= stack_data.map{|s| s['Name']}.sort
    end

    def stack_data
      @stack_data ||= begin
        JSON.parse(`aws opsworks describe-stacks`)['Stacks']
      end
    end

    def stack_id
      stack = stack_data.select{|s| s['Name'].downcase == @stack_name.downcase}.first
      if stack
        stack['StackId']
      else
        raise "Stack not found.  Available opsworks stacks: #{all_stack_names}"
      end
    end

    def set_revision_in_opsworks_app
      timestamped_puts "Setting revision #{@revision}"
      cmd = "aws opsworks update-app --app-id #{app_id(stack_id)} --app-source Revision=#{@revision}"
      timestamped_puts "#{cmd}"
      `#{cmd}`
    end

    def app_id(stack_id)
      JSON.parse(`aws opsworks describe-apps --stack-id=#{stack_id}`)['Apps'].select{|a| a['Type'] == @app_type}.first['AppId']
    end

    def timestamped_puts(str)
      puts "#{Time.now}  #{str}"
    end

    def deployed_by
      git_user = `git config --global user.name`.chomp
      git_email = `git config --global user.email`.chomp
      "#{git_user} (#{git_email})"
    end

    def deploy_comment
      "--comment \"rev. #{@revision}, deployed by #{deployed_by}\" "
    end

    def deploy_command
      { :Name => "deploy" }.to_json.gsub('"', "\\\"")
    end

    def monitor_deployment(deployment_id)
      deployment_finished = false
      status = ""
      while !deployment_finished
        response = describe_deployments(deployment_id)
        response["Deployments"].each do |deployment|
          next if deployment["DeploymentId"] != deployment_id
          status = deployment["Status"]
          timestamped_puts "Status: #{status}"
          deployment_finished = true if deployment["Status"].downcase != "running"
        end
        sleep(15) unless deployment_finished
      end
      timestamped_puts "Deployment #{status}"
      status
    end

    def describe_deployments(deployment_id)
      cmd = "aws opsworks describe-deployments --deployment-ids #{deployment_id}"
      JSON.parse(`#{cmd}`)
    end

    def start_deployment
      app_id = app_id(stack_id)

      cmd = "aws opsworks create-deployment --app-id #{app_id} " +
          "--stack-id #{stack_id} " +
          "--command \"#{deploy_command}\" " +
          "--instance-ids #{relevant_instance_ids(stack_id).join(' ')} " +
          deploy_comment

      timestamped_puts "Starting deployment..."
      timestamped_puts cmd

      response = JSON.parse(`#{cmd}`)
      response["DeploymentId"]
    end

    def post_deployment_to_hipchat(msg)
      room_id = (@hipchat_room_id || ENV['HIPCHAT_ROOM_ID']).to_i
      auth_token = @hipchat_auth_token || ENV['HIPCHAT_AUTH_TOKEN']

      return unless room_id > 0 && auth_token

      post_data = {
        :name => "Deployments",
        :privacy => 'private',
        :is_archived => false,
        :is_guest_accessible => true,
        :topic => 'curl',
        :message => msg,
        :color => 'green',
        :owner => { :id => 5 }
      }

      url = "https://api.hipchat.com/v2/room/#{room_id}/notification"
      cmd = "curl --header \"content-type: application/json\" --header \"Authorization: Bearer #{auth_token}\" -X POST -d \"#{post_data.to_json.gsub('"', '\\"')}\" #{url}"
      puts cmd
      `#{cmd}`
    end

    def layer_instance_ids(layer_ids)
      layer_ids.map do |layer_id|
        JSON.parse(`aws opsworks describe-instances --layer-id=#{layer_id}`)['Instances'].map{|i| i['InstanceId']}
      end.flatten
    end

    def relevant_instance_ids(stack_id)
      layer_instance_ids(relevant_app_layer_ids(stack_id))
    end

    def relevant_app_layer_ids(stack_id)
      stack_layers(stack_id).select{|l| l['Name'] =~ /#{@app_layer_name_regex}/i}.map{|layer_data| layer_data['LayerId']}
    end

    def stack_layers(stack_id)
      JSON.parse(`aws opsworks describe-layers --stack-id=#{stack_id}`)['Layers']
    end

    def opsworks_app_types
      [
        'aws-flow-ruby',
        'java',
        'rails',
        'php',
        'nodejs',
        'static',
        'other',
      ]
    end

  end
end
