module Fog
  module Google
    class Compute
      class Mock
        def list_instance_group_instances(_group, _zone)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def list_instance_group_instances(group_name, zone)
          @compute.list_instance_group_instances(@project,
                                                 zone,
                                                 group_name)
        end
      end
    end
  end
end
