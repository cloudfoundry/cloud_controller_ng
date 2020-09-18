require 'cloud_controller/yaml_config'
require 'cloud_controller/errors/details'

module CloudController
  module Errors
    module V3
      class HardCodedDetails
        def self.yaml_file_path
          File.join(File.expand_path('../../../../errors', __dir__), 'v3.yml')
        end

        HARD_CODED_DETAILS = DetailsLoader.load_by_name(yaml_file_path)

        def self.details
          HARD_CODED_DETAILS
        end
      end

      class Details < CloudController::Errors::Details
        def hard_coded_details
          V3::HardCodedDetails.details
        end
      end
    end
  end
end
