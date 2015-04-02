module VCAP::CloudController
  class AppStop
    def initialize(user, user_email)
      @user = user
      @user_email = user_email
    end

    def stop(app)
      app.db.transaction do
        app.update(desired_state: 'STOPPED')

        Event.create({
          type: 'audit.app.stop',
          actee: app.guid,
          actee_type: 'v3-app',
          actee_name: app.name,
          actor: @user.guid,
          actor_type: 'user',
          actor_name: @user_email,
          space_guid: app.space_guid,
          organization_guid: app.space.organization.guid,
          timestamp: Sequel::CURRENT_TIMESTAMP,
        })

        # this will force a query, may want to eager load processes in
        # AppFetcher
        app.processes.each do |process|
          process.update({
            state: 'STOPPED',
          })
        end
      end
    end
  end
end
