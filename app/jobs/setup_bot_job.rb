class SetupBotJob < Job
  def perform(bot_instance_id)
    @instance = BotInstance.find(bot_instance_id)

    case @instance.provider
    when 'slack' then setup_slack_bot!
    end
  end

  private
  def setup_slack_bot!
    slack = Slack.new(@instance.token)
    auth_info = slack.call('auth.test', :get)
    if auth_info['ok']
      @instance.update_attributes!(
        uid: auth_info['user_id'],
        state: 'enabled',
        instance_attributes: {
          team_id: auth_info['team_id'],
          team_name: auth_info['team'],
          team_url: auth_info['url']
        }
      )
      @instance.import_users!
    end
  end
end