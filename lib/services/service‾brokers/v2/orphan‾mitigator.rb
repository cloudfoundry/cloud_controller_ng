require 'jobs/services/delete_orphaned_binding'
require 'jobs/services/delete_orphaned_instance'
require 'jobs/services/delete_orphaned_key'

module VCAP::Services
  module ServiceBrokers
    module V2
      class OrphanMitigator
        def cleanup_failed_provision(client_attrs, service_instance)
          orphan_deprovision_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedInstance.new(
            'service-instance-deprovision',
            client_attrs,
            service_instance.guid,
            service_instance.service_plan.guid
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(orphan_deprovision_job, opts).enqueue
        end

        def cleanup_failed_bind(client_attrs, service_binding)
          binding_info = VCAP::CloudController::Jobs::Services::OrphanedBindingInfo.new(service_binding)
          unbind_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedBinding.new(
            'service-instance-unbind',
            client_attrs,
            binding_info
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(unbind_job, opts).enqueue
        end

        def cleanup_failed_key(client_attrs, service_key)
          key_delete_job = VCAP::CloudController::Jobs::Services::DeleteOrphanedKey.new(
            'service-key-delete',
            client_attrs,
            service_key.guid,
            service_key.service_instance.guid
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(key_delete_job, opts).enqueue
        end
      end
    end
  end
end
