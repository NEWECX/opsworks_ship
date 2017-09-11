module AwsDeploymentHelper

  def timestamped_puts(str)
    puts "#{Time.now}  #{str}"
  end

  def deployed_by
    git_user = `git config --global user.name`.chomp
    git_email = `git config --global user.email`.chomp
    "#{git_user} (#{git_email})"
  end

  def syntax
    puts "Arguments: #{method(:initialize).parameters.map{|p| "#{p.last} (#{p.first})"}.join(' ')}"
    puts "\n"
    puts "Valid stacks: #{all_stack_names}}"
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
    output_per_server_status_descriptions(deployment_id)
    status
  end

  def start_deployment(command)
    app_id = app_id(stack_id)

    cmd = "aws opsworks create-deployment --app-id #{app_id} " +
        "--stack-id #{stack_id} " +
        "--command \"#{command}\" " +
        "--instance-ids #{relevant_instance_ids(stack_id).join(' ')} " +
        deploy_comment

    timestamped_puts "Running command... #{command}"
    timestamped_puts cmd

    response = JSON.parse(`#{cmd}`)
    response["DeploymentId"]
  end

  def deploy_comment
    "--comment \"rev. #{@revision}, deployed by #{deployed_by}\" "
  end

  def output_per_server_status_descriptions(deployment_id)
    per_server_status_descriptions(deployment_id).each do |description|
      timestamped_puts description
      puts ''
    end
  end

end
