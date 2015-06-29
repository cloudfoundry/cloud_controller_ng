require 'actions/services/locks/updater_lock'

module VCAP::CloudController
  class ServiceInstanceUpdate
    KEYS_TO_UPDATE_CC_ONLY = %w(tags name space_guid)

    def initialize(accepts_incomplete: false, services_event_repository: nil)
      @accepts_incomplete = accepts_incomplete
      @services_event_repository = services_event_repository
    end

    def update_service_instance(service_instance, request_attrs)
      lock = UpdaterLock.new(service_instance)
      lock.lock!

      cached_service_instance = cache_service_instance(service_instance)
      previous_values = cache_previous_values(service_instance)

      update_cc_only_attrs(service_instance, request_attrs)

      if update_broker_needed?(request_attrs, cached_service_instance['service_plan_guid'])
        handle_broker_update(cached_service_instance, lock, previous_values, request_attrs, service_instance)
        update_deferred_attrs(service_instance, service_plan_guid: request_attrs.fetch('service_plan_guid', false))
      else
        lock.synchronous_unlock!
      end

      unless service_instance.operation_in_progress?
        @services_event_repository.record_service_instance_event(:update, service_instance, request_attrs)
      end
    ensure
      lock.unlock_and_fail! if lock.needs_unlock?
    end

    private

    def update_broker_needed?(attrs, old_service_plan_guid)
      return true if attrs['parameters']
      return false if !attrs['service_plan_guid']

      attrs['service_plan_guid'] != old_service_plan_guid
    end

    def handle_broker_update(cached_service_instance, lock, previous_values, request_attrs, service_instance)
      err = update_broker(@accepts_incomplete, request_attrs, service_instance, previous_values)

      if err
        reset_service_instance_to_cached(service_instance, cached_service_instance)
        raise err
      end

      if service_instance.operation_in_progress?
        job = build_fetch_job(service_instance, request_attrs)
        lock.enqueue_unlock!(job)
      else
        lock.synchronous_unlock!
      end
    end

    def update_broker(accepts_incomplete, request_attrs, service_instance, previous_values)
      if request_attrs.key?('service_plan_guid')
        service_plan = ServicePlan.find(guid: request_attrs['service_plan_guid'])
      else
        service_plan = service_instance.service_plan
      end

      response, err = service_instance.client.update(
          service_instance,
          service_plan,
          accepts_incomplete: accepts_incomplete,
          arbitrary_parameters: request_attrs['parameters'],
          previous_values: previous_values
      )

      service_instance.last_operation.update_attributes(response[:last_operation])

      err
    end

    def update_deferred_attrs(service_instance, service_plan_guid:)
      if service_plan_guid && !service_instance.operation_in_progress?
        service_instance.update_service_instance(service_plan: ServicePlan.find(guid: service_plan_guid))
      end
    end

    def update_cc_only_attrs(service_instance, request_attrs)
      service_instance.update_service_instance(request_attrs.slice(*KEYS_TO_UPDATE_CC_ONLY))
    end

    def cache_service_instance(service_instance)
      cached_service_instance = service_instance.values.stringify_keys
      cached_service_instance['service_plan_guid'] = service_instance.service_plan.guid
      cached_service_instance['space_guid'] = service_instance.space.guid
      cached_service_instance['tags'] = service_instance.tags
      cached_service_instance
    end

    def cache_previous_values(service_instance)
      {
          plan_id: service_instance.service_plan.broker_provided_id,
          service_id: service_instance.service.broker_provided_id,
          organization_id: service_instance.organization.guid,
          space_id: service_instance.space.guid
      }
    end

    def reset_service_instance_to_cached(service_instance, cached_service_instance)
      update_cc_only_attrs(service_instance, cached_service_instance)
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
      attributes_to_update = request_attrs.slice(*KEYS_TO_UPDATE_CC_ONLY)

      if !accepts_incomplete
        attributes_to_update.merge! successful_sync_operation
      end

      attributes_to_update
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
