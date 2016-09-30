module VCAP::CloudController
  module V2
    class AppCreate
      def initialize(access_validator:)
        @access_validator = access_validator
      end

      def create(request_attrs)
        process = nil

        AppModel.db.transaction do
          app = AppModel.create(
            name:                  request_attrs['name'],
            space_guid:            request_attrs['space_guid'],
            environment_variables: request_attrs['environment_json'],
          )

          create_lifecycle(app, request_attrs)

          process = App.new(
            guid:                    app.guid,
            production:              request_attrs['production'],
            memory:                  request_attrs['memory'],
            instances:               request_attrs['instances'],
            disk_quota:              request_attrs['disk_quota'],
            state:                   request_attrs['state'],
            command:                 request_attrs['command'],
            console:                 request_attrs['console'],
            debug:                   request_attrs['debug'],
            health_check_type:       request_attrs['health_check_type'],
            health_check_timeout:    request_attrs['health_check_timeout'],
            diego:                   request_attrs['diego'],
            enable_ssh:              request_attrs['enable_ssh'],
            docker_credentials_json: request_attrs['docker_credentials_json'],
            ports:                   request_attrs['ports'],
            route_guids:             request_attrs['route_guids'],
            app:                     app
          )

          validate_custom_buildpack!(process)
          validate_package_is_uploaded!(process)

          process.save

          @access_validator.validate_access(:create, process, request_attrs)
        end

        process
      end

      private

      def create_lifecycle(app, request_attrs)
        buildpack_type_requested = request_attrs.key?('buildpack') || request_attrs.key?('stack_guid')
        docker_type_requested    = request_attrs.key?('docker_image')

        if docker_type_requested
          create_message = PackageCreateMessage.new({ type: 'docker', app_guid: app.guid, data: { image: request_attrs['docker_image'] } })
          PackageCreate.create_without_event(create_message)
        elsif buildpack_type_requested || !docker_type_requested
          app.buildpack_lifecycle_data = BuildpackLifecycleDataModel.new(
            buildpack: request_attrs['buildpack'],
            stack:     get_stack_name(request_attrs['stack_guid']),
          )
          app.save
        end
      end

      def get_stack_name(stack_guid)
        stack      = Stack.find(guid: stack_guid)
        stack_name = stack.present? ? stack.name : Stack.default.name
        stack_name
      end

      def validate_custom_buildpack!(process)
        if process.buildpack.custom? && custom_buildpacks_disabled?
          raise CloudController::Errors::ApiError.new_from_details('AppInvalid', 'custom buildpacks are disabled')
        end
      end

      def custom_buildpacks_disabled?
        VCAP::CloudController::Config.config[:disable_custom_buildpacks]
      end

      def validate_package_is_uploaded!(process)
        if process.needs_package_in_current_state? && !process.package_available?
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'bits have not been uploaded')
        end
      end
    end
  end
end
