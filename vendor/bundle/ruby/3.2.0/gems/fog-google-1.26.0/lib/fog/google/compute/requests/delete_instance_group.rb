module Fog
  module Google
    class Compute
      class Mock
        def delete_instance_group(_group_name, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_instance_group(group_name, zone)
          @compute.delete_instance_group(@project, zone, group_name)
        end
      end
    end
  end
end
