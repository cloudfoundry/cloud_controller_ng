module VCAP::CloudController
  class AppStart
    class DropletNotFound < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_start')
    end

    def start(app)
      droplet = DropletModel.find(guid: app.desired_droplet_guid)
      raise DropletNotFound if droplet.nil?

      package = PackageModel.find(guid: droplet.package_guid)
      package_hash = package.nil? ? 'unknown' : package.package_hash

      app.db.transaction do
        app.update(desired_state: 'STARTED')

        @logger.info("Started app #{app.name} #{app.guid}")
        Event.create({
          type: 'audit.app.start',
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

        app.processes.each do |process|
          process.update({
            state: 'STARTED',
            package_hash: package_hash,
            package_state: 'STAGED',
            package_pending_since: nil,
            environment_json: app.environment_variables
          })
        end
      end
    end
  end
end
