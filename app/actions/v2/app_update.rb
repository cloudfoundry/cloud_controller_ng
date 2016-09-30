require 'actions/v2/app_stop'

module VCAP::CloudController
  module V2
    class AppUpdate
      def initialize(access_validator:, stagers:)
        @access_validator = access_validator
        @stagers          = stagers
      end

      def update(app, process, request_attrs)
        app.db.transaction do
          process.lock!
          app.lock!

          @access_validator.validate_access(:read_for_update, process, request_attrs)

          validate_not_changing_lifecycle_type!(process, request_attrs)

          update_app(app, request_attrs)
          update_lifecycle(app, process, request_attrs)
          assign_process_values(process, request_attrs)

          validate_package_is_uploaded!(process)

          process.save
          app.reload
          process.reload

          @access_validator.validate_access(:update, process, request_attrs)

          start_or_stop(app, request_attrs)
          prepare_to_stage(app) if staging_necessary?(process, request_attrs)
        end

        stage(process) if staging_necessary?(process, request_attrs)
      end

      private

      def assign_process_values(process, request_attrs)
        mass_assign = request_attrs.slice('production', 'memory', 'instances', 'disk_quota', 'state',
          'command', 'console', 'debug', 'health_check_type', 'health_check_timeout', 'diego', 'enable_ssh',
          'docker_credentials_json', 'ports', 'route_guids')

        process.set_all(mass_assign)
      end

      def update_app(app, request_attrs)
        app.name                  = request_attrs['name'] if request_attrs.key?('name')
        app.space_guid            = request_attrs['space_guid'] if request_attrs.key?('space_guid')
        app.environment_variables = request_attrs['environment_json'] if request_attrs.key?('environment_json')
        app.save
      end

      def update_lifecycle(app, process, request_attrs)
        buildpack_type_requested = request_attrs.key?('buildpack') || request_attrs.key?('stack_guid')
        docker_type_requested    = request_attrs.key?('docker_image')

        if buildpack_type_requested
          app.lifecycle_data.buildpack = request_attrs['buildpack'] if request_attrs.key?('buildpack')

          if request_attrs.key?('stack_guid')
            app.lifecycle_data.stack = Stack.find(guid: request_attrs['stack_guid']).try(:name)
            app.update(droplet: nil)
          end

          app.lifecycle_data.save
          validate_custom_buildpack!(process.reload)

        elsif docker_type_requested && !case_insensitive_equals(process.docker_image, request_attrs['docker_image'])
          create_message = PackageCreateMessage.new({ type: 'docker', app_guid: app.guid, data: { image: request_attrs['docker_image'] } })
          PackageCreate.create_without_event(create_message)
        end
      end

      def prepare_to_stage(app)
        app.update(droplet_guid: nil)
      end

      def stage(process)
        V2::AppStage.new(stagers: @stagers).stage(process)
      end

      def start_or_stop(app, request_attrs)
        if request_attrs.key?('state')
          case request_attrs['state']
          when 'STARTED'
            AppStart.start_without_event(app)
          when 'STOPPED'
            V2::AppStop.stop(app, @stagers)
          end
        end
      end

      def case_insensitive_equals(str1, str2)
        str1.casecmp(str2) == 0
      end

      def validate_not_changing_lifecycle_type!(process, request_attrs)
        buildpack_type_requested = request_attrs.key?('buildpack') || request_attrs.key?('stack_guid')
        docker_type_requested    = request_attrs.key?('docker_image')

        type_is_docker    = process.app.lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
        type_is_buildpack = !type_is_docker

        if (type_is_docker && buildpack_type_requested) || (type_is_buildpack && docker_type_requested)
          raise CloudController::Errors::ApiError.new_from_details('AppInvalid', 'Lifecycle type cannot be changed')
        end
      end

      def validate_package_is_uploaded!(process)
        if process.needs_package_in_current_state? && !process.package_available?
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'bits have not been uploaded')
        end
      end

      def validate_custom_buildpack!(process)
        if process.buildpack.custom? && custom_buildpacks_disabled?
          raise CloudController::Errors::ApiError.new_from_details('AppInvalid', 'custom buildpacks are disabled')
        end
      end

      def custom_buildpacks_disabled?
        VCAP::CloudController::Config.config[:disable_custom_buildpacks]
      end

      def staging_necessary?(process, request_attrs)
        request_attrs.key?('state') && process.needs_staging?
      end
    end
  end
end
