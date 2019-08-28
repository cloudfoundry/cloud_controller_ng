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
    class NoDefaultDomain < StandardError; end

    SERVICE_BINDING_TYPE = 'app'.freeze

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.first(guid: app_guid)
      app_instance_not_found!(app_guid) unless app

      message.manifest_process_update_messages.each do |manifest_process_update_msg|
        if manifest_process_update_msg.requested_keys == [:type] && manifest_process_update_msg.type == 'web'
          # ignore trivial messages, most likely from manifest
          next
        end

        process_type = manifest_process_update_msg.type
        process = find_process(app, process_type) || create_process(app, manifest_process_update_msg, process_type)

        process_update = ProcessUpdate.new(@user_audit_info, manifest_triggered: true)
        process_update.update(process, manifest_process_update_msg, ManifestStrategy)
      end

      message.manifest_process_scale_messages.each do |manifest_process_scale_msg|
        process = find_process(app, manifest_process_scale_msg.type)
        process.skip_process_version_update = true if manifest_process_scale_msg.requested?(:memory)
        process_scale = ProcessScale.new(@user_audit_info, process, manifest_process_scale_msg.to_process_scale_message, manifest_triggered: true)
        process_scale.scale
      end

      message.sidecar_create_messages.each do |sidecar_create_message|
        sidecar = find_sidecar(app, sidecar_create_message.name)
        if sidecar
          SidecarUpdate.update(sidecar, sidecar_create_message)
        else
          SidecarCreate.create(app.guid, sidecar_create_message)
        end
      end

      app_update_message = message.app_update_message
      lifecycle = AppLifecycleProvider.provide_for_update(app_update_message, app)
      AppUpdate.new(@user_audit_info, manifest_triggered: true).update(app, app_update_message, lifecycle)

      update_routes(app, message)

      AppPatchEnvironmentVariables.new(@user_audit_info, manifest_triggered: true).patch(app, message.app_update_environment_variables_message)

      create_service_bindings(message.manifest_service_bindings_message, app) if message.services.present?
      app
    end

    private

    def find_process(app, process_type)
      ProcessModel.where(app: app, type: process_type).order(Sequel.asc(:created_at), Sequel.asc(:id)).last
    end

    def create_process(app, manifest_process_update_msg, process_type)
      ProcessCreate.new(@user_audit_info, manifest_triggered: true).create(app, {
        type: process_type,
        command: manifest_process_update_msg.command
      })
    end

    def find_sidecar(app, sidecar_name)
      app.sidecars_dataset.where(name: sidecar_name).last
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
        domain_name = get_default_domain_name(app)

        route = "#{random_host}.#{domain_name}"

        random_route_message = ManifestRoutesUpdateMessage.new(routes: [{ route: route }])
        ManifestRouteUpdate.update(app.guid, random_route_message, @user_audit_info)
      end

      if update_message.default_route && existing_routes.empty?
        domain_name = get_default_domain_name(app)

        route = "#{app.name}.#{domain_name}"

        random_route_message = ManifestRoutesUpdateMessage.new(routes: [{ route: route }])
        ManifestRouteUpdate.update(app.guid, random_route_message, @user_audit_info)
      end
    end

    def get_default_domain_name(app)
      domain_name = app.organization.default_domain&.name
      raise NoDefaultDomain.new('No default domains available') unless domain_name

      domain_name
    end

    def create_service_bindings(manifest_service_bindings_message, app)
      action = ServiceBindingCreate.new(@user_audit_info, manifest_triggered: true)
      manifest_service_bindings_message.manifest_service_bindings.each do |manifest_service_binding|
        service_instance = app.space.find_visible_service_instance_by_name(manifest_service_binding.name)
        service_instance_not_found!(manifest_service_binding.name) unless service_instance
        next if binding_exists?(service_instance, app)

        action.create(
          app,
          service_instance,
          ServiceBindingCreateMessage.new(type: SERVICE_BINDING_TYPE, data: { parameters: manifest_service_binding.parameters }),
          volume_services_enabled?,
          false
        )
      end
    end

    def binding_exists?(service_instance, app)
      ServiceBinding.where(service_instance: service_instance, app: app).present?
    end

    def app_instance_not_found!(app_guid)
      raise CloudController::Errors::NotFound.new_from_details('ResourceNotFound', "App with guid '#{app_guid}' not found")
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
