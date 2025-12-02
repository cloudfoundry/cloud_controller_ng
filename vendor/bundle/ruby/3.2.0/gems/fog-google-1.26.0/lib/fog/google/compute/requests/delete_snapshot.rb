module Fog
  module Google
    class Compute
      class Mock
        def delete_snapshot(_snapshot_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_snapshot(snapshot_name)
          @compute.delete_snapshot(@project, snapshot_name)
        end
      end
    end
  end
end
