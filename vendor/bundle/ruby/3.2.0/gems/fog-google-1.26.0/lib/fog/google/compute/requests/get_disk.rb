module Fog
  module Google
    class Compute
      class Mock
        def get_disk(_disk_name, _zone_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Get a disk resource by name from the specified zone
        # https://cloud.google.com/compute/docs/reference/latest/disks/get
        #
        # @param zone_name [String] Zone the disk resides in
        def get_disk(disk_name, zone_name)
          zone_name = zone_name.split("/")[-1] if zone_name.start_with? "http"
          @compute.get_disk(@project, zone_name, disk_name)
        end
      end
    end
  end
end
