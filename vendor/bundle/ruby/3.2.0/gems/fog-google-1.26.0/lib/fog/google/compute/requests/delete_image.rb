module Fog
  module Google
    class Compute
      class Mock
        def delete_image(_image_name, _project = @project)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def delete_image(image_name, project = @project)
          @compute.delete_image(project, image_name)
        end
      end
    end
  end
end
