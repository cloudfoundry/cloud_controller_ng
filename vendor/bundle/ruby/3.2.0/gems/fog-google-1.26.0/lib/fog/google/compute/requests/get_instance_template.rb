module Fog
  module Google
    class Compute
      class Mock
        def get_instance_template(_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_instance_template(name)
          @compute.get_instance_template(@project, name)
        end
      end
    end
  end
end
