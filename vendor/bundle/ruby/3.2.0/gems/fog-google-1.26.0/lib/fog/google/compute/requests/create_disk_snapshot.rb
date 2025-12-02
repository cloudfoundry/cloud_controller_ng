module Fog
  module Google
    class Compute
      class Mock
        def create_disk_snapshot(_snapshot_name, _disk, _zone, _snapshot = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def create_disk_snapshot(snapshot_name, disk, zone, snapshot = {})
          @compute.create_disk_snapshot(
            @project, zone, disk,
            ::Google::Apis::ComputeV1::Snapshot.new(
              **snapshot.merge(name: snapshot_name)
            )
          )
        end
      end
    end
  end
end
