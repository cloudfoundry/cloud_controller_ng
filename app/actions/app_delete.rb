module VCAP::CloudController
  class AppDelete
    def delete(app_dataset, user, user_email)
      app_dataset.each do |app_model|
        packages = PackageModel.where(app_guid: app_model.guid)
        PackageDelete.new.delete(packages)

        droplets = DropletModel.where(app_guid: app_model.guid)
        DropletDelete.new.delete(droplets)

        space = Space.find(guid: app_model.space_guid)
        processes = App.where(app_guid: app_model.guid)
        ProcessDelete.new.delete(processes, space, user, user_email)
      end

      app_dataset.destroy
    end
  end
end
