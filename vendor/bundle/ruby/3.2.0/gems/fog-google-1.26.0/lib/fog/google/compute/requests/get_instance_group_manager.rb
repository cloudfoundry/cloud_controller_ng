module Fog
  module Google
    class Compute
      class Mock
        def get_instance_group_manager(_name, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_instance_group_manager(name, zone)
          @compute.get_instance_group_manager(@project, zone, name)
        end
      end
    end
  end
end
