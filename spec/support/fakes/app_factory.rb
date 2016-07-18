module VCAP
  module CloudController
    class AppFactory
      def self.make(*args)
        parent_app_attributes = args.extract_options!.symbolize_keys
        attributes            = parent_app_attributes.slice!(:name, :space, :environment_json, :stack)
        package_attributes    = attributes
        attributes            = package_attributes.slice!(:docker_image)

        defaults   = { metadata: {} }
        attributes = defaults.merge(attributes)

        parent_app = nil
        if parent_app_attributes.any?
          buildpack_keys = {}

          if parent_app_attributes.key?(:environment_json)
            parent_app_attributes[:environment_variables] = parent_app_attributes[:environment_json]
            parent_app_attributes.delete(:environment_json)
          end
          if parent_app_attributes.key?(:stack)
            buildpack_keys[:stack] = parent_app_attributes[:stack].name
            parent_app_attributes.delete(:stack)
          end

          parent_app = VCAP::CloudController::AppModel.make(parent_app_attributes)
          parent_app.lifecycle_data.update(buildpack_keys) if buildpack_keys.any?
        else
          parent_app = VCAP::CloudController::AppModel.make
        end
        attributes[:app] = parent_app

        args << attributes

        package = if package_attributes.empty?
                    VCAP::CloudController::PackageModel.make(app: parent_app, state: PackageModel::READY_STATE, package_hash: Sham.guid)
                  else
                    VCAP::CloudController::PackageModel.make(:docker, app: parent_app, docker_image: package_attributes[:docker_image])
                  end

        droplet = DropletModel.make(:staged, app: parent_app, package: package)
        parent_app.update(droplet_guid: droplet.guid)


        VCAP::CloudController::App.make(*args)
      end
    end
  end
end
