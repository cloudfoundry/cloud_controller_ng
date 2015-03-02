module VCAP::CloudController
  class ServiceInstanceProvisioner
    class Unauthorized < StandardError; end
    class ServiceInstanceCannotAccessServicePlan < StandardError; end
    class InvalidRequest < StandardError; end
    class InvalidServicePlan < StandardError; end
    class InvalidSpace < StandardError; end

    def initialize(services_event_repository, access_validator, logger, access_context)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
      @access_context = access_context
    end

    def create_service_instance(request_attrs, params)
      raise InvalidRequest unless request_attrs

      validate_create_action(request_attrs, params)

      service_instance = ManagedServiceInstance.new(request_attrs)
      attributes_to_update = service_instance.client.provision(
        service_instance,
        accepts_incomplete: accepts_incomplete?(params),
        event_repository_opts: {
          user: @access_context.user,
          user_email: @access_context.user_email
        },
        request_attrs: request_attrs,
      )

      begin
        service_instance.save_with_operation(attributes_to_update)
      rescue => e
        safe_deprovision_instance(service_instance)
        raise e
      end

      if (!accepts_incomplete?(params)) || service_instance.last_operation.state != 'in progress'
        @services_event_repository.record_service_instance_event(:create, service_instance, request_attrs)
      end

      service_instance
    end

    private

    def safe_deprovision_instance(service_instance)
      # this needs to go into a retry queue
      service_instance.client.deprovision(service_instance)
    rescue => e
      @logger.error "Unable to deprovision #{service_instance}: #{e}"
    end

    def accepts_incomplete?(params)
      params['accepts_incomplete'] == 'true'
    end

    def current_user_can_manage_plan(plan_guid)
      ServicePlan.user_visible(@access_context.user, @access_context.roles.admin?).filter(guid: plan_guid).count > 0
    end

    def requested_space(request_attrs)
      space = Space.filter(guid: request_attrs['space_guid']).first
      raise InvalidSpace unless space
      space
    end

    def validate_create_action(request_attrs, params)
      service_plan_guid = request_attrs['service_plan_guid']
      organization = requested_space(request_attrs).organization

      raise InvalidServicePlan if ServicePlan.find(guid: service_plan_guid).nil?
      raise Unauthorized unless current_user_can_manage_plan(service_plan_guid)

      unless ServicePlan.organization_visible(organization).filter(guid: service_plan_guid).count > 0
        raise ServiceInstanceCannotAccessServicePlan
      end

      service_instance = ManagedServiceInstance.new(request_attrs)
      @access_validator.validate_access(:create, service_instance)

      raise Sequel::ValidationFailed.new(service_instance) unless service_instance.valid?

      raise InvalidRequest unless ['true', 'false', nil].include? params['accepts_incomplete']
    end
  end
end
