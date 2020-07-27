require 'jobs/v3/delete_service_instance_job'

module VCAP::CloudController
  module V3
    class ServiceInstanceDelete
      class AssociationNotEmptyError < StandardError; end

      class InstanceSharedError < StandardError; end

      def initialize(event_repo)
        @service_event_repository = event_repo
      end

      def delete(service_instance)
        association_not_empty! if service_instance.has_bindings? || service_instance.has_keys? || service_instance.has_routes?

        cannot_delete_shared_instances! if service_instance.shared?

        lock = DeleterLock.new(service_instance)

        job = case service_instance
              when ManagedServiceInstance
                asynchronous_destroy(service_instance)
              when UserProvidedServiceInstance
                lock.lock!
                synchronous_destroy(service_instance, lock)
              end

        job
      end

      private

      def synchronous_destroy(service_instance, lock)
        lock.unlock_and_destroy!
        service_event_repository.record_user_provided_service_instance_event(:delete, service_instance, {})
        nil
      end

      def asynchronous_destroy(service_instance)
        delete_job = V3::DeleteServiceInstanceJob.new(
          service_instance.guid,
          service_event_repository.user_audit_info)

        pollable_job = Jobs::Enqueuer.new(delete_job, queue: Jobs::Queues.generic).enqueue_pollable

        pollable_job.guid
      end

      def association_not_empty!
        raise AssociationNotEmptyError
      end

      def cannot_delete_shared_instances!
        raise InstanceSharedError
      end

      attr_reader :service_event_repository
    end
  end
end
