module CloudController
  module Errors
    class ApiError < StandardError
      attr_accessor :args
      attr_accessor :details
      attr_accessor :error_prefix

      def self.new_from_details(name, *args)
        details = Details.new(name)
        new(details, args)
      end

      def initialize(details=nil, args=nil)
        @details = details
        @args = args
      end

      def message
        return unless args && details

        formatted_args = args.map do |arg|
          (arg.is_a? Array) ? arg.map(&:to_s).join(', ') : arg.to_s
        end

        "#{error_prefix}#{sprintf(details.message_format, *formatted_args)}"
      end

      def code
        details.try(:code)
      end

      def name
        details.try(:name)
      end

      def response_code
        details.try(:response_code)
      end
    end
  end
end
