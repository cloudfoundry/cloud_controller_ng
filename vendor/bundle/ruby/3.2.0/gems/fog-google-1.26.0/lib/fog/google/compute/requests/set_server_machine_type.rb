module Fog
  module Google
    class Compute
      class Mock
        def set_server_machine_type(_instance, _zone, _machine_type)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def set_server_machine_type(instance, zone, machine_type)
          request = ::Google::Apis::ComputeV1::InstancesSetMachineTypeRequest.new
          zone = zone.split("/")[-1]
          machine_type = machine_type.split("/")[-1]
          request.machine_type = "zones/#{zone}/machineTypes/#{machine_type}"
          @compute.set_instance_machine_type(@project, zone, instance, request)
        end
      end
    end
  end
end
