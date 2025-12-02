module Fog
  module Google
    class Compute
      class Mock
        def get_instance_group(_group_name, _zone, _project = @project)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_instance_group(group_name, zone, project = @project)
          @compute.get_instance_group(project, zone, group_name)
        end
      end
    end
  end
end
