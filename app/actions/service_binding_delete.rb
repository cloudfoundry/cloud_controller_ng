require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceBindingDelete
    include VCAP::CloudController::LockCheck

    def initialize(user_audit_info, accepts_incomplete=false)
      @user_audit_info = user_audit_info
      @accepts_incomplete = accepts_incomplete
    end

    def foreground_delete_request(service_binding)
      errors = delete(service_binding)
      raise errors.first unless errors.empty?
    end

    def background_delete_request(service_binding)
      Jobs::Enqueuer.new(
        Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, self),
        queue: 'cc-generic'
      ).enqueue
    end

    def delete(service_bindings)
      bindings_to_delete = Array(service_bindings)

      errors = each_with_error_aggregation(bindings_to_delete) do |service_binding|
        raise_if_instance_locked(service_binding.service_instance)
        raise_if_binding_locked(service_binding)

        @broker_response = remove_from_broker(service_binding)
        if @broker_response[:async] && @accepts_incomplete
          service_binding.save_with_new_operation({ type: 'delete', state: 'in progress', broker_provided_operation: @broker_response[:operation] })

          job = VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, @user_audit_info, {})
          enqueuer = Jobs::Enqueuer.new(job, queue: 'cc-generic')
          enqueuer.enqueue
        else
          Repositories::ServiceBindingEventRepository.record_delete(service_binding, @user_audit_info)
          service_binding.destroy
        end
      end

      errors
    end

    def broker_responded_async_for_accepts_incomplete_false?
      @broker_response&.[](:async) && !@accepts_incomplete
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_delete')
    end

    def remove_from_broker(service_binding)
      client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)
      client.unbind(service_binding, @user_audit_info.user_guid, @accepts_incomplete)
    rescue => e
      logger.error("Failed unbinding #{service_binding.guid}: #{e.message}")
      raise e
    end

    def each_with_error_aggregation(list)
      errors = []
      list.each do |item|
        begin
          yield(item)
        rescue => e
          errors << e
        end
      end
      errors
    end
  end
end
