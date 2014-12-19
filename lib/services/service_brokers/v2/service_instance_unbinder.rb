module VCAP::CloudController
  module Jobs::Runtime
    class ServiceInstanceUnbinder
      def self.unbind(client, binding)
        unbind_job = ServiceInstanceUnbind.new('service-instance-unbind', client, binding)
        Delayed::Job.enqueue(unbind_job, queue: 'cc-generic', run_at: Delayed::Job.db_time_now)
        unbind_job
      end
    end
  end
end
