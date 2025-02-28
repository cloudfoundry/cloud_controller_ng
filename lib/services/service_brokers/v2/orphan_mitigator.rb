require 'jobs/v2/services/delete_orphaned_binding'
require 'jobs/v2/services/delete_orphaned_instance'
require 'jobs/v2/services/delete_orphaned_key'

module VCAP::Services
  module ServiceBrokers
    module V2
      class OrphanMitigator
        def cleanup_failed_provision(service_instance)
          orphan_deprovision_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedInstance.new(
            'service-instance-deprovision',
            service_instance.guid,
            service_instance.service_plan.guid
          )

          VCAP::CloudController::Jobs::GenericEnqueuer.shared.enqueue(orphan_deprovision_job, run_at: Delayed::Job.db_time_now)
        end

        def cleanup_failed_bind(service_binding)
          binding_info = VCAP::CloudController::Jobs::Services::OrphanedBindingInfo.new(service_binding)
          unbind_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedBinding.new(
            'service-instance-unbind',
            binding_info
          )

          VCAP::CloudController::Jobs::GenericEnqueuer.shared.enqueue(unbind_job, run_at: Delayed::Job.db_time_now)
        end

        def cleanup_failed_key(service_key)
          key_delete_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedKey.new(
            'service-key-delete',
            service_key.guid,
            service_key.service_instance.guid
          )

          VCAP::CloudController::Jobs::GenericEnqueuer.shared.enqueue(key_delete_job, run_at: Delayed::Job.db_time_now)
        end
      end
    end
  end
end
