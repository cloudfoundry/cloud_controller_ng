require 'actions/services/service_key_delete'
require 'actions/services/route_binding_delete'
require 'actions/services/locks/deleter_lock'

module VCAP::CloudController
  class ServiceInstanceDelete
    def initialize(accepts_incomplete: false, event_repository:, multipart_delete: false)
      @accepts_incomplete = accepts_incomplete
      @event_repository = event_repository
      @multipart_delete = multipart_delete
    end

    def delete(service_instance_dataset)
      # COMMENT-FOR-REVIEW:
      # type of `service_instance_dataset' should be Sequel::Dataset, but some times it is set as an Array. e.g.
      # spec/unit/actions/services/service_instance_delete_spec.rb:318 `errors = service_instance_delete.delete([service_instance_1])'
      #
      # You can't operate data in on sequel #each, #each_with_object of dataset on mssql, you need to retrieve all data before operations,
      # otherwise you will get an error indicating that two different queries are using the same connection at the same time.
      service_instance_dataset = service_instance_dataset.all unless service_instance_dataset.class == Array
      service_instance_dataset.each_with_object([]) do |service_instance, errors_accumulator|
        binding_errors = delete_service_bindings(service_instance)
        binding_errors.concat delete_service_keys(service_instance)
        binding_errors.concat delete_route_bindings(service_instance)

        errors_accumulator.concat binding_errors

        if binding_errors.empty?
          instance_errors = delete_service_instance(service_instance)

          if service_instance.operation_in_progress? && @multipart_delete && instance_errors.empty?
            errors_accumulator.push CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
          end

          errors_accumulator.concat instance_errors
        end
      end
    end

    private

    def delete_service_instance(service_instance)
      errors = []

      if !service_instance.exists?
        return []
      end

      begin
        lock = DeleterLock.new(service_instance)
        lock.lock!

        attributes_to_update = service_instance.client.deprovision(
          service_instance,
          accepts_incomplete: @accepts_incomplete
        )

        if attributes_to_update[:last_operation][:state] == 'succeeded'
          lock.unlock_and_destroy!
        else
          lock.enqueue_unlock!(attributes_to_update, build_fetch_job(service_instance))
        end
      rescue => e
        errors << e
      ensure
        lock.unlock_and_fail! if lock.needs_unlock?
      end

      errors
    end

    def delete_route_bindings(service_instance)
      route_bindings_dataset = RouteBinding.where(service_instance_id: service_instance.id)
      RouteBindingDelete.new.delete(route_bindings_dataset)
    end

    def delete_service_bindings(service_instance)
      ServiceBindingDelete.new(@event_repository.user_audit_info).delete(service_instance.service_bindings)
    end

    def delete_service_keys(service_instance)
      ServiceKeyDelete.new.delete(service_instance.service_keys_dataset)
    end

    def build_fetch_job(service_instance)
      VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
        'service-instance-state-fetch',
        service_instance.client.attrs,
        service_instance.guid,
        @event_repository.user_audit_info,
        {},
      )
    end
  end
end
