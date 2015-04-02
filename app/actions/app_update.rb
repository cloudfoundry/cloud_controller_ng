module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
    end

    def update(app, message)
      app.db.transaction do
        app.lock!
        updated_fields = []

        if message['name']
          app.name = message['name']
          updated_fields << 'name'
        end

        if message['environment_variables']
          app.environment_variables = message['environment_variables']
          updated_fields << 'environment_variables'
        end

        if message['desired_droplet_guid']
          droplet = DropletModel.find(guid: message['desired_droplet_guid'])
          raise DropletNotFound if droplet.nil?
          raise DropletNotFound if droplet.app_guid != app.guid
          app.desired_droplet_guid = message['desired_droplet_guid']
          updated_fields << 'desired_droplet_guid'
        end

        Event.create({
          type: 'audit.app.update',
          actee: app.guid,
          actee_type: 'v3-app',
          actee_name: app.name,
          actor: @user.guid,
          actor_type: 'user',
          actor_name: @user_email,
          space_guid: app.space_guid,
          organization_guid: app.space.organization.guid,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            updated_fields: updated_fields
          }
        })

        app.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
