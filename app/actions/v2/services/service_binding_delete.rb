require 'actions/services/locks/lock_check'
require 'repositories/service_binding_event_repository'
require 'jobs/v2/services/service_binding_state_fetch'

module VCAP::CloudController
  class ServiceBindingDelete
    include LockCheck

    def initialize(user_audit_info, accepts_incomplete=false)
      @user_audit_info = user_audit_info
      @accepts_incomplete = accepts_incomplete
    end

    def foreground_delete_request(service_binding)
      errors, warnings = delete(service_binding)
      raise errors.first unless errors.empty?

      warnings
    end

    def background_delete_request(service_binding)
      Jobs::Enqueuer.new(
        Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, self),
        queue: Jobs::Queues.generic
      ).enqueue
    end

    def delete(service_bindings)
      bindings_to_delete = Array(service_bindings)

      warnings_accumulator = []
      errors = each_with_error_aggregation(bindings_to_delete) do |service_binding|
        raise_if_instance_locked(service_binding.service_instance)

        if service_binding.operation_in_progress? && service_binding.service_binding_operation.type != 'create'
          raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', service_binding.app.name, service_binding.service_instance.name)
        end

        broker_response = remove_from_broker(service_binding)
        if broker_response[:async] && @accepts_incomplete
          service_binding.save_with_new_operation({ type: 'delete', state: 'in progress', broker_provided_operation: broker_response[:operation] })

          job = VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, @user_audit_info, {})
          enqueuer = Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic)
          enqueuer.enqueue
          Repositories::ServiceBindingEventRepository.record_start_delete(service_binding, @user_audit_info)
        else
          service_binding.destroy
          Repositories::ServiceBindingEventRepository.record_delete(service_binding, @user_audit_info)
        end

        if broker_responded_async_for_accepts_incomplete_false?(broker_response)
          warnings_accumulator << ['The service broker responded asynchronously to the unbind request, but the accepts_incomplete query parameter was false or not given.',
                                   'The service binding may not have been successfully deleted on the service broker.'].join(' ')
        end
      end

      [errors, warnings_accumulator]
    end

    def can_return_warnings?
      true
    end

    private

    def broker_responded_async_for_accepts_incomplete_false?(broker_response)
      broker_response[:async] && !@accepts_incomplete
    end

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_delete')
    end

    def remove_from_broker(service_binding)
      client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
      client.unbind(service_binding, user_guid: @user_audit_info.user_guid, accepts_incomplete: @accepts_incomplete)
    rescue => e
      logger.error("Failed unbinding #{service_binding.guid}: #{e.message}")
      raise_wrapped_error(service_binding, e)
    end

    def raise_wrapped_error(service_binding, err)
      raise err.exception(
        "An unbind operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} failed: #{err.message}")
    end

    def each_with_error_aggregation(list)
      errors = []
      list.each do |item|
        yield(item)
      rescue => e
        errors << e
      end
      errors
    end
  end
end
