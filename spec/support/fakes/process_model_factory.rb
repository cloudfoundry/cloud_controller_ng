module VCAP
  module CloudController
    class ProcessModelFactory
      APP_ATTRIBUTES     = %i(name space environment_json stack enable_ssh).freeze
      PACKAGE_ATTRIBUTES = %i(docker_image docker_credentials).freeze

      class << self
        def make(*args)
          options = args.extract_options!.symbolize_keys
          options[:enable_ssh] = true unless options.key?(:enable_ssh) # FIXME
          parent_app_attributes = options.slice(*APP_ATTRIBUTES)
          package_attributes    = options.slice(*PACKAGE_ATTRIBUTES)
          process_attributes    = options.except(*APP_ATTRIBUTES, *PACKAGE_ATTRIBUTES)

          defaults           = { metadata: {} }
          process_attributes = defaults.merge(process_attributes)

          parent_app                = make_parent_app(package_attributes, parent_app_attributes, process_attributes)
          process_attributes[:app]  = parent_app
          process_attributes[:guid] = parent_app.guid if process_attributes[:type] == 'web' || process_attributes[:type].nil?

          package = make_package(package_attributes, parent_app)

          build   = BuildModel.make(app: parent_app, package: package)
          droplet = DropletModel.make(app: parent_app, build: build, package: package)
          parent_app.update(droplet_guid: droplet.guid)

          VCAP::CloudController::ProcessModel.make(*args, process_attributes)
        end

        private

        def make_parent_app(package_attributes, parent_app_attributes, process_attributes)
          return process_attributes[:app] if process_attributes[:app]

          parent_app_blueprint_type = package_attributes[:docker_image].present? ? :docker : nil
          if process_attributes.key?(:state)
            parent_app_attributes[:desired_state] = process_attributes[:state]
          end

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

            parent_app = VCAP::CloudController::AppModel.make(parent_app_blueprint_type, parent_app_attributes)
            parent_app.lifecycle_data.update(buildpack_keys) if buildpack_keys.any?
          else
            parent_app = VCAP::CloudController::AppModel.make(parent_app_blueprint_type, parent_app_attributes)
          end
          process_attributes[:app] = parent_app
          parent_app
        end

        def make_package(package_attributes, parent_app)
          if package_attributes.empty?
            VCAP::CloudController::PackageModel.make(app: parent_app, state: PackageModel::READY_STATE, package_hash: Sham.guid)
          else
            docker_credentials = package_attributes[:docker_credentials].nil? ? {} : package_attributes[:docker_credentials]
            VCAP::CloudController::PackageModel.make(:docker, app: parent_app,
                                                              docker_image:                                        package_attributes[:docker_image],
                                                              docker_username:                                     docker_credentials['username'],
                                                              docker_password:                                     docker_credentials['password'])
          end
        end
      end
    end
  end
end
