require 'actions/services/locks/updater_lock'

module VCAP::CloudController
  class ServiceInstanceUpdate
    KEYS_TO_UPDATE_CC_ONLY = %w(tags name space_guid).freeze
    KEYS_TO_UPDATE_CC = KEYS_TO_UPDATE_CC_ONLY + ['service_plan_guid']

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

      if update_broker_needed?(request_attrs, cached_service_instance['service_plan_guid'], service_instance)
        handle_broker_update(cached_service_instance, lock, previous_values, request_attrs, service_instance)
        update_deferred_attrs(service_instance, request_attrs)
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

    def update_broker_needed?(attrs, old_service_plan_guid, service_instance)
      parameters_changed = attrs['parameters']
      service_name_changed = attrs['name'] && service_instance.service.allow_context_updates
      maintenance_info_version_changed = attrs['maintenance_info'] &&
        attrs['maintenance_info']['version'] != service_instance.maintenance_info&.fetch('version', nil)
      service_plan_changed = attrs['service_plan_guid'] && attrs['service_plan_guid'] != old_service_plan_guid

      parameters_changed || service_name_changed || maintenance_info_version_changed || service_plan_changed
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
        @services_event_repository.record_service_instance_event(:start_update, service_instance, request_attrs)
      else
        lock.synchronous_unlock!
      end
    end

    def update_broker(accepts_incomplete, request_attrs, service_instance, previous_values)
      service_plan = extract_current_or_updated_service_plan(service_instance, request_attrs)
      maintenance_info = extract_updated_maintenance_info(service_plan, request_attrs)

      client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })
      response, err = client.update(
        service_instance,
        service_plan,
        accepts_incomplete: accepts_incomplete,
        arbitrary_parameters: request_attrs['parameters'],
        previous_values: previous_values,
        maintenance_info: maintenance_info,
      )

      service_instance.last_operation.update_attributes(response[:last_operation])

      if response.key?(:dashboard_url)
        service_instance.update_service_instance(dashboard_url: response[:dashboard_url])
      end

      err
    end

    def extract_current_or_updated_service_plan(service_instance, request_attrs)
      if plan_update_requested?(request_attrs)
        ServicePlan.find(guid: request_attrs['service_plan_guid'])
      else
        service_instance.service_plan
      end
    end

    def extract_updated_maintenance_info(service_plan, request_attrs)
      maintenance_info = if plan_update_requested?(request_attrs)
                           service_plan.maintenance_info
                         else
                           request_attrs['maintenance_info']
                         end

      get_version_only(from: maintenance_info)
    end

    def plan_update_requested?(request_attrs)
      request_attrs.key?('service_plan_guid')
    end

    def get_version_only(from:)
      from&.slice('version')
    end

    def update_deferred_attrs(service_instance, request_attrs)
      unless service_instance.operation_in_progress?
        service_plan = extract_current_or_updated_service_plan(service_instance, request_attrs)
        maintenance_info = extract_updated_maintenance_info(service_plan, request_attrs)

        attrs_to_update = if plan_update_requested?(request_attrs)
                            { service_plan: service_plan, maintenance_info: maintenance_info }
                          elsif maintenance_info
                            { maintenance_info: maintenance_info }
                          end

        service_instance.update_service_instance(attrs_to_update) if attrs_to_update
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
      previous_values = {
        plan_id: service_instance.service_plan.broker_provided_id,
        service_id: service_instance.service.broker_provided_id,
        organization_id: service_instance.organization.guid,
        space_id: service_instance.space.guid,
      }

      maintenance_info = get_version_only(from: service_instance.maintenance_info)
      previous_values[:maintenance_info] = maintenance_info if maintenance_info

      previous_values
    end

    def reset_service_instance_to_cached(service_instance, cached_service_instance)
      update_cc_only_attrs(service_instance, cached_service_instance)
    end

    def build_fetch_job(service_instance, request_attrs)
      VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
        'service-instance-state-fetch',
        service_instance.guid,
        @services_event_repository.user_audit_info,
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
