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
        PackageDelete.new(app_model.packages_dataset).delete
        DropletDelete.new(app_model.droplets_dataset).delete
        ProcessDelete.new(app_model.processes_dataset, app_model.space, user, user_email).delete
      end

      app_dataset.destroy
    end
  end
end
