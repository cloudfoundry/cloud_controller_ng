module VCAP
  module Errors
    class ApiError < StandardError
      attr_accessor :args
      attr_accessor :details

      def self.new_from_details(name, *args)
        details = Details.new(name)
        api_error = new
        api_error.details = details
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

      def name
        details.name
      end

      def response_code
        details.response_code
      end
    end
  end
end


