require 'actions/service_binding_delete'
require 'actions/deletion_errors'

module VCAP::CloudController
  class ServiceInstanceDelete
    def initialize(accepts_incomplete: false, event_repository_opts: {})
      @accepts_incomplete = accepts_incomplete
      @event_repository_opts = event_repository_opts
    end

    def delete(service_instance_dataset)
      service_instance_dataset.each_with_object([]) do |service_instance, errs|
        errs = delete_service_instance(service_instance, errs)
        errs
      end
    end

    private

    def delete_service_instance(service_instance, errs)
      if service_instance.user_provided_instance?
        begin
          service_instance.destroy
          return errs
        rescue => e
          errs << e
          return errs
        end
      end

      errors = ServiceBindingDelete.new.delete(service_instance.service_bindings_dataset)
      errs.concat(errors)
      if errors.empty?
        lock = DeleterLock.new(service_instance)
        lock.lock!

        needs_unlock = true
        begin
          attributes_to_update, poll_interval = service_instance.client.deprovision(service_instance, accepts_incomplete: @accepts_incomplete)
          if attributes_to_update[:last_operation][:state] == 'succeeded'
            lock.unlock_and_destroy!
            needs_unlock = false
            return errs
          end

          service_instance.save_with_operation(attributes_to_update)

          job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            'service-instance-state-fetch',
            service_instance.client.attrs,
            service_instance.guid,
            @event_repository_opts,
            {},
            poll_interval,
          )

          lock.enqueue_unlock!(attributes_to_update, job)
          needs_unlock = false
        rescue => e
          errs << e
          lock.unlock_and_fail!
          needs_unlock = false
        ensure
          lock.unlock_and_fail! if needs_unlock
        end
      end
      errs
    end
  end
end
