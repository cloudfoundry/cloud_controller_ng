require 'actions/process_create'
require 'actions/process_scale'
require 'actions/process_update'
require 'actions/service_binding_create'
require 'actions/manifest_route_update'
require 'cloud_controller/strategies/manifest_strategy'
require 'cloud_controller/app_manifest/manifest_route'
require 'cloud_controller/random_route_generator'

module VCAP::CloudController
  class AppApplyManifest
    SERVICE_BINDING_TYPE = 'app'.freeze

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)

      message.manifest_process_update_messages.each do |manifest_process_update_msg|
        process_type = manifest_process_update_msg.type
        process = find_process(app, process_type) || create_process(app, manifest_process_update_msg, process_type)

        process_update = ProcessUpdate.new(@user_audit_info, manifest_triggered: true)
        process_update.update(process, manifest_process_update_msg, ManifestStrategy)
      end

      message.manifest_process_scale_messages.each do |manifest_process_scale_msg|
        process = find_process(app, manifest_process_scale_msg.type)
        process_scale = ProcessScale.new(@user_audit_info, process, manifest_process_scale_msg.to_process_scale_message, manifest_triggered: true)
        process_scale.scale
      end

      app_update_message = message.app_update_message
      lifecycle = AppLifecycleProvider.provide_for_update(app_update_message, app)
      AppUpdate.new(@user_audit_info, manifest_triggered: true).update(app, app_update_message, lifecycle)

      update_routes(app, message)

      AppPatchEnvironmentVariables.new(@user_audit_info, manifest_triggered: true).patch(app, message.app_update_environment_variables_message)

      create_service_bindings(message.services, app) if message.services.present?
      app
    end

    private

    def find_process(app, process_type)
      ProcessModel.find(app: app, type: process_type)
    end

    def create_process(app, manifest_process_update_msg, process_type)
      ProcessCreate.new(@user_audit_info, manifest_triggered: true).create(app, {
        type: process_type,
        command: manifest_process_update_msg.command
      })
    end

    def update_routes(app, message)
      update_message = message.manifest_routes_update_message
      existing_routes = RouteMappingModel.where(app_guid: app.guid).all

      if update_message.no_route
        RouteMappingDelete.new(@user_audit_info, manifest_triggered: true).delete(existing_routes)
        return
      end

      if update_message.routes
        ManifestRouteUpdate.update(app.guid, update_message, @user_audit_info)
        return
      end

      if update_message.random_route && existing_routes.empty?
        random_host = "#{app.name}-#{RandomRouteGenerator.new.route}"
        domain = SharedDomain.first.name
        route = "#{random_host}.#{domain}"

        random_route_message = ManifestRoutesUpdateMessage.new(routes: [{ route: route }])
        ManifestRouteUpdate.update(app.guid, random_route_message, @user_audit_info)
      end
    end

    def create_service_bindings(services, app)
      action = ServiceBindingCreate.new(@user_audit_info, manifest_triggered: true)
      services.each do |name|
        service_instance = ServiceInstance.find(name: name)
        service_instance_not_found!(name) unless service_instance
        next if binding_exists?(service_instance, app)

        action.create(
          app,
          service_instance,
          ServiceBindingCreateMessage.new(type: SERVICE_BINDING_TYPE),
          volume_services_enabled?,
          false
        )
      end
    end

    def binding_exists?(service_instance, app)
      ServiceBinding.where(service_instance: service_instance, app: app).present?
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
