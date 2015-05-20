require 'actions/services/locks/updater_lock'

module VCAP::CloudController
  class ServiceInstanceUpdate
    def initialize(accepts_incomplete: false, services_event_repository: nil)
      @accepts_incomplete = accepts_incomplete
      @services_event_repository = services_event_repository
    end

    def update_service_instance(service_instance, request_attrs)
      lock = UpdaterLock.new(service_instance)
      lock.lock!

      begin
        attributes_to_update, err = get_attributes_to_update(service_instance, request_attrs, @accepts_incomplete)

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

      if !@accepts_incomplete || !service_instance.operation_in_progress?
        @services_event_repository.record_service_instance_event(:update, service_instance, request_attrs)
      end
    end

    private

    def build_fetch_job(service_instance, request_attrs)
      VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
          'service-instance-state-fetch',
          service_instance.client.attrs,
          service_instance.guid,
          @services_event_repository,
          request_attrs,
      )
    end

    def get_attributes_to_update(service_instance, request_attrs, accepts_incomplete)
      return successful_sync_operation, nil if request_attrs.empty?

      new_name = request_attrs['name']
      return { name: new_name }.merge(successful_sync_operation), nil if new_name

      space_guid = request_attrs['space_guid']
      return { space_guid: space_guid }.merge(successful_sync_operation), nil if space_guid

      service_plan_guid = request_attrs['service_plan_guid'] ? request_attrs['service_plan_guid'] : service_instance.service_plan_guid
      plan = ServicePlan.find(guid: service_plan_guid)

      plan_changed = plan != service_instance.service_plan
      arbitrary_params_present = request_attrs['parameters']

      return successful_sync_operation, nil if !plan_changed && !arbitrary_params_present

      service_instance.client.update_service_plan(
          service_instance,
          plan,
          accepts_incomplete: accepts_incomplete,
          arbitrary_parameters: request_attrs['parameters']
      )
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
