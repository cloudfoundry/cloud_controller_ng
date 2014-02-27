module VCAP
  module Errors
    class ApiError < StandardError
      attr_accessor :name
      attr_accessor :args

      def self.new_from_details(name, *args)
        api_error = new
        api_error.name = name
        api_error.args = args
        api_error
      end

      def message
        formatted_args = args.map do |arg|
          (arg.is_a? Array) ? arg.map(&:to_s).join(', ') : arg.to_s
        end
        sprintf(details.message_format, *formatted_args)
      end

      def code
        details.code
      end

      def response_code
        details.response_code
      end

      private

      def details
        Details.new(name)
      end
    end
  end
end


