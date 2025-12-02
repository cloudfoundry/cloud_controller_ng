module Fog
  module Google
    class Compute
      class Mock
        def delete_instance_template(_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_instance_template(name)
          @compute.delete_instance_template(@project, name)
        end
      end
    end
  end
end
