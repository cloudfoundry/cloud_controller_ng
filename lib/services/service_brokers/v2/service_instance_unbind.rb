module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceInstanceUnbind < Struct.new(:name, :client, :binding)
        def perform
          client.unbind(binding)
        end

        def job_name_in_configuration
          :service_instance_unbind
        end

        def max_attempts
          3
        end
      end
    end
  end
end
