module Fog
  module Google
    class Compute
      class Mock
        def attach_disk(_instance, _zone, _disk = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def attach_disk(instance, zone, disk = {})
          @compute.attach_disk(
            @project, zone.split("/")[-1], instance,
            ::Google::Apis::ComputeV1::AttachedDisk.new(**disk)
          )
        end
      end
    end
  end
end
