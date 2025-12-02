module Fog
  module Google
    class Compute
      class Mock
        def get_disk_type(_disk, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_disk_type(disk, zone)
          @compute.get_disk_type(@project, zone.split("/")[-1], disk)
        end
      end
    end
  end
end
