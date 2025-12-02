module Fog
  module Google
    class Compute
      class Mock
        def detach_disk(_instance, _zone, _device_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def detach_disk(instance, zone, device_name)
          zone = zone.split("/")[-1]
          @compute.detach_disk(@project, zone, instance, device_name)
        end
      end
    end
  end
end
