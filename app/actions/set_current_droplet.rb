require 'cloud_controller/procfile'

module VCAP::CloudController
  class SetCurrentDroplet
    # class DropletNotFound < StandardError; end
    # class ProcfileNotFound < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.procfile_parse')
    end

    def update_to(app, droplet)
      app.db.transaction do
        app.lock!
        update_app(app, { desired_droplet_guid: droplet.guid })
        procfile_parse.process_procfile(app)
        app.save
      end

      app
    end

    private

    def procfile_parse
      ProcfileParse.new(@user, @user_email)
    end

    def update_app(app, fields)
      app.update(fields)
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
          updated_fields: fields
        }
      })
    end
  end
end
