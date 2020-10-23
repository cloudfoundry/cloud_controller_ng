require 'cloud_controller/yaml_config'

module CloudController
  module Errors
    class DetailsLoader
      def self.load_by_code(yaml_file_path)
        VCAP::CloudController::YAMLConfig.safe_load_file(yaml_file_path)
      end

      def self.load_by_name(yaml_file_path)
        details_by_name = {}
        load_by_code(yaml_file_path).each do |code, values|
          key = values['name']
          details_by_name[key] = values
          details_by_name[key]['code'] = code
          details_by_name[key].delete('name')
        end
        details_by_name
      end
    end

    module V2
      class HardCodedDetails
        def self.yaml_file_path
          File.join(File.expand_path('../../../errors', __dir__), 'v2.yml')
        end

        HARD_CODED_DETAILS = CloudController::Errors::DetailsLoader.load_by_name(yaml_file_path)

        def self.details
          HARD_CODED_DETAILS
        end
      end
    end

    class Details
      attr_accessor :name, :details_hash

      def hard_coded_details
        V2::HardCodedDetails.details
      end

      def initialize(name)
        @details_hash = hard_coded_details.fetch(name.to_s)
        @name = name
      end

      def code
        details_hash['code']
      end

      def response_code
        details_hash['http_code']
      end

      def message_format
        details_hash['message']
      end
    end
  end
end
