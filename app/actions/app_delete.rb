module VCAP::CloudController
  class AppDelete
    attr_reader :user, :user_email

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_delete')
    end

    def delete(apps)
      apps = [apps] unless apps.is_a?(Array)

      apps.each do |app|
        PackageDelete.new.delete(packages_to_delete(app))
        DropletDelete.new.delete(droplets_to_delete(app))
        ProcessDelete.new(app.space, user, user_email).delete(processes_to_delete(app))
        app.remove_all_routes

        @logger.info("Deleted app #{app.name} #{app.guid}")
        Event.create({
          type: 'audit.app.delete',
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
        app.destroy
      end
    end

    private

    def packages_to_delete(app_model)
      app_model.packages_dataset.select(:"#{PackageModel.table_name}__guid", :"#{PackageModel.table_name}__id").all
    end

    def droplets_to_delete(app_model)
      app_model.droplets_dataset.select(:"#{DropletModel.table_name}__guid", :"#{DropletModel.table_name}__id").all
    end

    def processes_to_delete(app_model)
      app_model.processes_dataset.
        select(:"#{App.table_name}__guid",
        :"#{App.table_name}__id",
        :"#{App.table_name}__app_guid",
        :"#{App.table_name}__name").all
    end
  end
end
