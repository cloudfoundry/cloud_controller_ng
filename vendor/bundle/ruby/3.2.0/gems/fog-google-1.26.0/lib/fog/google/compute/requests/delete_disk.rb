module Fog
  module Google
    class Compute
      class Mock
        def delete_disk(_disk_name, _zone_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Delete a disk resource
        # https://cloud.google.com/compute/docs/reference/latest/disks/delete
        #
        # @param disk_name [String] Name of the disk to delete
        # @param zone_name [String] Zone the disk reside in
        def delete_disk(disk_name, zone_name)
          zone_name = zone_name.split("/")[-1] if zone_name.start_with? "http"
          @compute.delete_disk(@project, zone_name, disk_name)
        end
      end
    end
  end
end
