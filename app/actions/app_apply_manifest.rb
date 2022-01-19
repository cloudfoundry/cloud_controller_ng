require 'actions/mixins/bindings_delete'
require 'actions/process_create'
require 'actions/process_scale'
require 'actions/process_update'
require 'actions/service_credential_binding_app_create'
require 'actions/service_credential_binding_delete'
require 'actions/manifest_route_update'
require 'cloud_controller/strategies/manifest_strategy'
require 'cloud_controller/app_manifest/manifest_route'
require 'cloud_controller/random_route_generator'

module VCAP::CloudController
  class AppApplyManifest
    include V3::BindingsDeleteMixin

    class Error < StandardError; end
    class NoDefaultDomain < StandardError; end
    class ServiceBindingError < StandardError; end
    class ServiceBrokerRespondedAsyncWhenNotAllowed < StandardError; end
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
        validate_name_dns_compliant!(app.name)
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

    def validate_name_dns_compliant!(name)
      prefix = 'Failed to create default route from app name:'

      if name.present? && name.length > 63
        error!(prefix + ' Host cannot exceed 63 characters')
      end

      unless name&.match(/\A[\w\-]+\z/)
        error!(prefix + ' Host must be either "*" or contain only alphanumeric characters, "_", or "-"')
      end
    end

    def create_service_bindings(manifest_service_bindings_message, app)
      manifest_service_bindings_message.manifest_service_bindings.each do |manifest_service_binding|
        service_instance = app.space.find_visible_service_instance_by_name(manifest_service_binding.name)
        service_instance_not_found!(manifest_service_binding.name) unless service_instance
        binding_being_deleted!(service_instance, app)
        next if binding_exists?(service_instance, app)

        begin
          binding_message = create_binding_message(service_instance.guid, app.guid, manifest_service_binding)
          action = V3::ServiceCredentialBindingAppCreate.new(@user_audit_info, binding_message.audit_hash, manifest_triggered: true)
          binding = action.precursor(
            service_instance,
            app: app,
            volume_mount_services_enabled: volume_services_enabled?,
            message: binding_message)

          begin
            result = action.bind(binding, parameters: binding_message.parameters)
            if result[:async]
              raise ServiceBrokerRespondedAsyncWhenNotAllowed
            end
          rescue ServiceBrokerRespondedAsyncWhenNotAllowed,
                 V3::ServiceBindingCreate::BindingNotRetrievable

            raise ServiceBrokerRespondedAsyncWhenNotAllowed.new('The service broker responded asynchronously, but async bindings are not supported.')
          end
        rescue => e
          if binding
            delete_bindings([binding], user_audit_info: @user_audit_info)
          end

          raise_binding_error!(service_instance, e.message)
        end
      end
    end

    def create_binding_message(service_instance_guid, app_guid, manifest_service_binding)
      ServiceCredentialAppBindingCreateMessage.new(
        type: SERVICE_BINDING_TYPE,
        name: manifest_service_binding.binding_name,
        parameters: manifest_service_binding.parameters,
        relationships: {
          service_instance: {
            data: {
              guid: service_instance_guid
            }
          },
          app: {
            data: {
              guid: app_guid
            }
          }
        }
      )
    end

    def raise_binding_error!(service_instance, message)
      error_message = "For service '#{service_instance.name}': #{message}"
      raise ServiceBindingError.new(error_message)
    end

    def binding_exists?(service_instance, app)
      binding = ServiceBinding.first(service_instance: service_instance, app: app)
      binding && !binding.create_failed?
    end

    def binding_being_deleted!(service_instance, app)
      binding = ServiceBinding.first(service_instance: service_instance, app: app)
      if binding && binding.operation_in_progress? && binding.last_operation.type == 'delete'
        raise_binding_error!(service_instance, 'An existing binding is being deleted. Try recreating the binding later.')
      end
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

    def error!(message)
      raise Error.new(message)
    end
  end
end
