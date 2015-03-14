module VCAP
  module Errors
    class Details
      def self.yaml_file_path
        File.join(File.expand_path('../../../../vendor/errors', __FILE__), 'v2.yml')
      end

      def self.details_by_code
        YAML.load_file(yaml_file_path)
      end

      def self.details_by_name
        details_by_name = {}
        details_by_code.each do |code, values|
          key = values['name']
          details_by_name[key] = values
          details_by_name[key]['code'] = code
          details_by_name[key].delete('name')
        end
        details_by_name
      end

      HARD_CODED_DETAILS = details_by_name

      attr_accessor :name
      attr_accessor :details_hash

      def initialize(name)
        @details_hash = HARD_CODED_DETAILS.fetch(name.to_s)
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
