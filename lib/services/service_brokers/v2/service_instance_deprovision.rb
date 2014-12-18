module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceInstanceDeprovision < Struct.new(:name, :client, :instance)
        def perform
          client.deprovision(instance)
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
