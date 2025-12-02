module Fog
  module Google
    class Compute
      class Mock
        def insert_image(_image_name, _image = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_image(image_name, image = {}, project = @project)
          image = image.merge(:name => image_name)
          @compute.insert_image(
            project,
            ::Google::Apis::ComputeV1::Image.new(**image)
          )
        end
      end
    end
  end
end
