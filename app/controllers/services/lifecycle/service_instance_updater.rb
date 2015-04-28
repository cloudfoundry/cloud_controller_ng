require 'actions/locks/updater_lock'

module VCAP::CloudController
  class ServiceInstanceUpdater
    class InvalidRequest < StandardError; end
    class ServicePlanNotUpdatable < StandardError; end
    class InvalidServicePlan < StandardError; end
    class ServiceInstanceSpaceChangeNotAllowed < StandardError; end

    def initialize(services_event_repository, access_validator, logger, access_context)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
      @access_context = access_context
    end

    def update_service_instance(service_instance, request_attrs, accepts_incomplete)
      raise InvalidRequest unless request_attrs
      @access_validator.validate_access(:read_for_update, service_instance)
      @access_validator.validate_access(:update, service_instance)
      validate_update_request(service_instance, request_attrs)

      err = nil

      lock = UpdaterLock.new(service_instance)
      lock.lock!

      begin
        attributes_to_update, err = get_attributes_to_update(service_instance, request_attrs, accepts_incomplete)

        if attributes_to_update[:last_operation][:state] == 'in progress'
          job = build_fetch_job(service_instance, request_attrs)
          lock.enqueue_unlock!(attributes_to_update, job)
        else
          lock.synchronous_unlock!(attributes_to_update)
        end
      rescue
        lock.unlock_and_fail!
        raise
      end

      raise err if err

      if !accepts_incomplete || !service_instance.operation_in_progress?
        @services_event_repository.record_service_instance_event(:update, service_instance, request_attrs)
      end
    end

    def build_fetch_job(service_instance, request_attrs)
      VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
        'service-instance-state-fetch',
        service_instance.client.attrs,
        service_instance.guid,
        event_repository_opts,
        request_attrs
      )
    end

    private

    def get_attributes_to_update(service_instance, request_attrs, accepts_incomplete)
      return successful_sync_operation, nil if request_attrs.empty?

      new_name = request_attrs['name']
      return { name: new_name }.merge(successful_sync_operation), nil if new_name

      space_guid = request_attrs['space_guid']
      return { space_guid: space_guid }.merge(successful_sync_operation), nil if space_guid

      new_plan = ServicePlan.find(guid: request_attrs['service_plan_guid'])
      return successful_sync_operation, nil if new_plan == service_instance.service_plan

      service_instance.client.update_service_plan(
        service_instance,
        new_plan,
        accepts_incomplete: accepts_incomplete,
        parameters: request_attrs['parameters']
      )
    end

    def event_repository_opts
      {
        user: @access_context.user,
        user_email: @access_context.user_email
      }
    end

    def successful_sync_operation
      {
        last_operation: {
          state: 'succeeded',
          description: nil
        }
      }
    end

    def validate_update_request(service_instance, request_attrs)
      if request_attrs['space_guid'] && request_attrs['space_guid'] != service_instance.space.guid
        raise ServiceInstanceSpaceChangeNotAllowed
      end

      if request_attrs['service_plan_guid']
        old_plan = service_instance.service_plan
        raise ServicePlanNotUpdatable unless old_plan.service.plan_updateable

        new_plan = ServicePlan.find(guid: request_attrs['service_plan_guid'])
        raise InvalidServicePlan unless new_plan
      end
    end
  end
end
