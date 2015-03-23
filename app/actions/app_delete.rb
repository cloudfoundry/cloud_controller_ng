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
      end

      app_dataset.destroy
    end
  end
end
