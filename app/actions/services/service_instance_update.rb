require 'actions/services/locks/updater_lock'

module VCAP::CloudController
  class ServiceInstanceUpdate
    def initialize(accepts_incomplete: false, services_event_repository: nil)
      @accepts_incomplete = accepts_incomplete
      @services_event_repository = services_event_repository
      @instance_keys = %w(tags name service_plan_guid space_guid)
      @cached_service_instance = {}
    end

    def update_service_instance(service_instance, request_attrs)
      cache_service_instance(service_instance)

      lock = UpdaterLock.new(service_instance)
      lock.lock!

      begin
        service_instance.update_service_instance(request_attrs.slice(*@instance_keys))

        broker_response, err = update_broker(@accepts_incomplete, request_attrs, service_instance)
        if broker_response[:last_operation]
          service_instance.last_operation.update_attributes(broker_response[:last_operation])
        end
        raise err if err

        if broker_response.fetch(:last_operation, {}).fetch(:state, false) == 'in progress'
          attributes_to_update = get_attributes_to_update(request_attrs, @accepts_incomplete)
          service_instance.update_service_instance(attributes_to_update)
          job = build_fetch_job(service_instance, request_attrs)
          lock.enqueue_unlock!(job)
        end

        operation_attrs = service_instance.last_operation.values

        if !@accepts_incomplete || broker_response.empty?
          lock.synchronous_unlock!(operation_attrs)
        end
      rescue => err1
        begin
          if service_instance.errors.empty?
            reset_service_instance_to_cached(service_instance)
          end
        rescue => err2
          message = 'Error resetting the service instance: ' + err2.message
          message += 'Original error that caused the reset: ' + err1.message
          message += err1.backtrace.to_s
          raise Exception.new(message)
        ensure
          lock.unlock_and_fail!
          raise
        end
      end

      if !service_instance.operation_in_progress?
        @services_event_repository.record_service_instance_event(:update, service_instance, request_attrs)
      end
    end

    private

    def cache_service_instance(service_instance)
      @cached_service_instance = service_instance.values.stringify_keys
      @cached_service_instance['service_plan_guid'] = service_instance.service_plan.guid
      @cached_service_instance['space_guid'] = service_instance.space.guid
    end

    def reset_service_instance_to_cached(service_instance)
      service_instance.update_service_instance(@cached_service_instance.slice(*@instance_keys))
    end

    def build_fetch_job(service_instance, request_attrs)
      VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
          'service-instance-state-fetch',
          service_instance.client.attrs,
          service_instance.guid,
          @services_event_repository,
          request_attrs,
      )
    end

    def get_attributes_to_update(request_attrs, accepts_incomplete)
      attributes_to_update = request_attrs.slice(*@instance_keys)

      if !accepts_incomplete
        attributes_to_update.merge! successful_sync_operation
      end

      attributes_to_update
    end

    def update_broker(accepts_incomplete, request_attrs, service_instance)
      if request_attrs['service_plan_guid']
        service_plan_changed = (request_attrs['service_plan_guid'] != @cached_service_instance['service_plan_guid'])
      else
        service_plan_changed = false
      end
      arbitrary_params = request_attrs['parameters']

      if arbitrary_params || service_plan_changed
        response, error = service_instance.client.update_service_plan(
          service_instance,
          service_instance.service_plan,
          accepts_incomplete: accepts_incomplete,
          arbitrary_parameters: arbitrary_params
        )
        [response, error]
      else
        [{}, nil]
      end
    end

    def successful_sync_operation
      {
          last_operation: {
              state: 'succeeded',
              description: nil
          }
      }
    end
  end
end
