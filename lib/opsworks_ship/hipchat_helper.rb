module HipchatHelper

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

end
