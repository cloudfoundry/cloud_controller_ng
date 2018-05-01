require 'actions/process_scale'
require 'actions/service_binding_create'
require 'actions/manifest_route_update'
require 'cloud_controller/strategies/manifest_strategy'
require 'cloud_controller/app_manifest/manifest_route'

module VCAP::CloudController
  class AppApplyManifest
    SERVICE_BINDING_TYPE = 'app'.freeze

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)

      message.manifest_process_update_messages.each do |manifest_process_update_msg|
        process = ProcessModel.find(app: app, type: manifest_process_update_msg.type)
        ProcessUpdate.new(@user_audit_info).update(process, manifest_process_update_msg, ManifestStrategy)
      end

      message.manifest_process_scale_messages.each do |manifest_process_scale_msg|
        process = ProcessModel.find(app: app, type: manifest_process_scale_msg.type)
        ProcessScale.new(@user_audit_info, process, manifest_process_scale_msg.to_process_scale_message).scale
      end

      app_update_message = message.app_update_message
      lifecycle = AppLifecycleProvider.provide_for_update(app_update_message, app)
      AppUpdate.new(@user_audit_info).update(app, app_update_message, lifecycle)

      do_route_update(app, message)

      AppPatchEnvironmentVariables.new(@user_audit_info).patch(app, message.app_update_environment_variables_message)
      create_service_instances(message, app)
      app
    end

    private

    def do_route_update(app, message)
      update_message = message.manifest_routes_update_message
      existing_routes = RouteMappingModel.where(app_guid: app.guid).all

      if update_message.no_route
        RouteMappingDelete.new(@user_audit_info).delete(existing_routes)
        return
      end

      if update_message.routes
        ManifestRouteUpdate.update(app.guid, update_message, @user_audit_info)
        return
      end

      if update_message.random_route && existing_routes.size == 0
        qualifier = CloudController::DependencyLocator.instance.random_route_generator.route
        domain = Domain.first.name
        route = "#{app.name}-#{qualifier}.#{domain}"
        random_route_message = ManifestRoutesUpdateMessage.new(routes: [{ route: route }])
        ManifestRouteUpdate.update(app.guid, random_route_message, @user_audit_info)
      end
    end

    def create_service_instances(message, app)
      return unless message.services.present?

      action = ServiceBindingCreate.new(@user_audit_info)
      message.services.each do |name|
        service_instance = ServiceInstance.find(name: name)
        service_instance_not_found!(name) unless service_instance
        next if binding_exists?(service_instance, app)
        binding_message = service_binding_message(app, service_instance)
        action.create(app, service_instance, binding_message, volume_services_enabled?)
      end
    end

    def binding_exists?(service_instance, app)
      ServiceBinding.find(service_instance: service_instance, app: app)
    end

    # ServiceBindingCreate uses the app_guid and service_instance_guid for audit_hash, but there is different story for audit events
    # In manifests, unlike in the API endpoint, these parameters must be fetched from DB
    def service_binding_message(app, service)
      ServiceBindingCreateMessage.new({
        type: SERVICE_BINDING_TYPE,
        relationships: {
        },
        data: {
        }
      })
    end

    def service_instance_not_found!(name)
      raise CloudController::Errors::NotFound.new_from_details('ResourceNotFound', "Service instance '#{name}' not found")
    end

    def volume_services_enabled?
      VCAP::CloudController::Config.config.get(:volume_services_enabled)
    end

    def logger
      @logger ||= Steno.logger('cc.action.app_apply_manifest')
    end
  end
end
