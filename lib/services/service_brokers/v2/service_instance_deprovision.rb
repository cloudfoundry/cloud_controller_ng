module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceInstanceDeprovision < Struct.new(:name, :client, :service_instance)
        def perform
          client.deprovision(service_instance)
        end

        def job_name_in_configuration
          :service_instance_deprovision
        end

        def max_attempts
          3
        end
      end
    end
  end
end
