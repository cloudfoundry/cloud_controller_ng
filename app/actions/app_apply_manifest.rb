require 'actions/process_scale'
require 'actions/service_binding_create'
require 'cloud_controller/strategies/manifest_strategy'
require 'cloud_controller/app_manifest/route_domain_splitter'

module VCAP::CloudController
  class AppApplyManifest
    SERVICE_BINDING_TYPE = 'app'.freeze

    def initialize(user_audit_info, controller=nil)
      @controller = controller
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)
      ProcessScale.new(user_audit_info, app.web_process, message.process_scale_message).scale

      app_update_message = message.app_update_message
      lifecycle = AppLifecycleProvider.provide_for_update(app_update_message, app)
      AppUpdate.new(user_audit_info).update(app, app_update_message, lifecycle)

      ProcessUpdate.new(user_audit_info).update(app.web_process, message.manifest_process_update_message, ManifestStrategy)
      RouteUpdate.new(user_audit_info, controller).update(app.guid, message.manifest_routes_message)
      # message.manifest_routes_message.routes.each_value do |route|
      #   splitRoutes = RouteDomainSplitter.split(route)
      #
      #   the_domain_to_use = nil
      #   splitRoutes[:potential_domains].each do |name|
      #     # if route already exists, do nothing
      #     matching_domains = Domain.where(name: name).all.present?
      #     # if matching_domains
      #       # check the rest of the route, get valid host
      #       # use the domain to create the route, map route to app
      #       RouteCreate.new(access_validator: self, logger: logger).create_route(route_hash: {
      #         host: splitRoutes[:host],
      #         domain: { name: name},
      #         path: splitRoutes[:path]
      #       })
      #       RouteMappingCreate.new(user_audit_info, route, app.web_process)
      #       the_domain_to_use = name
      #     # end
      #
      #     # return error that domain doesn't exist
      #   end
      # end

      AppPatchEnvironmentVariables.new(user_audit_info).patch(app, message.app_update_environment_variables_message)
      create_service_instances(message, app)
      app
    end

    def logger
      @logger ||= Steno.logger('cc.action.app_apply_manifest')
    end

    private

    def create_service_instances(message, app)
      return unless message.services.present?

      action = ServiceBindingCreate.new(user_audit_info)
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

    attr_reader :user_audit_info
  end
end
