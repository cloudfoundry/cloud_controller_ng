module Fog
  module Google
    class Compute
      class Mock
        def get_image_from_family(_family, _project = @project)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Returns the latest non-deprecated image that is part of an image family.
        #
        # @param family [String] Name of the image family
        # @param project [String] Project the image belongs to.
        # @return Google::Apis::ComputeV1::Image
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/images/getFromFamily
        def get_image_from_family(family, project = @project)
          @compute.get_image_from_family(project, family)
        end
      end
    end
  end
end
