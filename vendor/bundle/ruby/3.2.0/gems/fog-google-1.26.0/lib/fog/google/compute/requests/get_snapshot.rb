module Fog
  module Google
    class Compute
      class Mock
        def get_snapshot(_snap_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_snapshot(snap_name, project = @project)
          raise ArgumentError.new "snap_name must not be nil." if snap_name.nil?
          @compute.get_snapshot(project, snap_name)
        end
      end
    end
  end
end
