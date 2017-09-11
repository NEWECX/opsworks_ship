module AwsDataHelper

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

  def app_id(stack_id)
    JSON.parse(`aws opsworks describe-apps --stack-id=#{stack_id}`)['Apps'].select{|a| a['Type'] == @app_type}.first['AppId']
  end

  def describe_deployments(deployment_id)
    cmd = "aws opsworks describe-deployments --deployment-ids #{deployment_id}"
    JSON.parse(`#{cmd}`)
  end

  def per_server_status_descriptions(deployment_id)
    JSON.parse(`aws opsworks describe-commands --deployment-id #{deployment_id}`)['Commands'].map{|deploy| "#{instance_name(deploy['InstanceId'])} - Status: #{deploy['Status']} - Log: #{deploy['LogUrl']}"}
  end

  def instance_name(instance_id)
    JSON.parse(`aws opsworks describe-instances --instance-id #{instance_id}`)['Instances'].first['Hostname']
  end

end
