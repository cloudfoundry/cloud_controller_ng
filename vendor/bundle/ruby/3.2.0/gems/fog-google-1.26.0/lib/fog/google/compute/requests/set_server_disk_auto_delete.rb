module Fog
  module Google
    class Compute
      class Mock
        def set_server_disk_auto_delete(_identity, _zone, _auto_delete, _device_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # @see https://cloud.google.com/compute/docs/reference/latest/instances/setDiskAutoDelete
        def set_server_disk_auto_delete(identity, zone, auto_delete, device_name)
          @compute.set_disk_auto_delete(
            @project,
            zone.split("/")[-1],
            identity,
            auto_delete,
            device_name
          )
        end
      end
    end
  end
end
