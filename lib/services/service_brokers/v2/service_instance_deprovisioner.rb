module VCAP::CloudController
  module Jobs::Runtime
    class ServiceInstanceDeprovisioner
      def self.deprovision(client, service_instance)
        deprovision_job = ServiceInstanceDeprovision.new('service-instance-deprovision', client, service_instance)
        Delayed::Job.enqueue(deprovision_job, queue: 'cc-generic', run_at: Delayed::Job.db_time_now)
        deprovision_job
      end
    end
  end
end
