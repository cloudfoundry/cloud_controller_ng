module Fog
  module Google
    class Compute
      class Mock
        def get_image(_image_name, _project = @project)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def get_image(image_name, project = @project)
          project = @project if project.nil?
          @compute.get_image(project, image_name)
        end
      end
    end
  end
end
