module VCAP::CloudController
  class AppDelete
    attr_reader :user, :user_email

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
    end

    def delete(app_dataset)
      app_dataset.each do |app_model|
        PackageDelete.new.delete(app_model.packages_dataset)
        DropletDelete.new.delete(app_model.droplets_dataset)
        ProcessDelete.new(app_model.space, user, user_email).delete(app_model.processes_dataset)
        app_model.remove_all_routes

        Event.create({
          type: 'audit.app.delete',
          actee: app_model.guid,
          actee_type: 'v3-app',
          actee_name: app_model.name,
          actor: @user.guid,
          actor_type: 'user',
          actor_name: @user_email,
          space_guid: app_model.space_guid,
          organization_guid: app_model.space.organization.guid,
          timestamp: Sequel::CURRENT_TIMESTAMP,
        })
      end

      app_dataset.destroy
    end
  end
end
