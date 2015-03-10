module VCAP::CloudController
  class AppDelete
    attr_reader :app_dataset, :user, :user_email

    def initialize(app_dataset, user, user_email)
      @app_dataset = app_dataset
      @user = user
      @user_email = user_email
    end

    def delete
      app_dataset.each do |app_model|
        PackageDelete.new.delete(app_model.packages_dataset)
        DropletDelete.new.delete(app_model.droplets_dataset)
        ProcessDelete.new.delete(app_model.processes_dataset, app_model.space, user, user_email)
      end

      app_dataset.destroy
    end
  end
end
