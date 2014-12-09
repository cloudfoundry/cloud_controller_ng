module VCAP
  module Errors
    class ApiError < StandardError
      attr_accessor :args
      attr_accessor :details
      attr_accessor :full_error_name

      def self.new_from_details(full_error_name, args = {})
        unless args.is_a? Hash
          if args.is_a? Array
            args = args.join(", ")
          end
          args = { string: args }
        end

        name = full_error_name.split(".").first

        details                   = Details.new(name)
        api_error                 = new
        api_error.details         = details
        api_error.full_error_name = full_error_name
        api_error.args            = args
        api_error
      end

      def self.setup_i18n(load_path, default_locale)
        I18n.enforce_available_locales = false
        I18n.load_path                 = load_path
        I18n.default_locale            = default_locale
        I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
        I18n.backend.reload!
      end

      def message
        return unless full_error_name
        translated_message = I18n.translate(full_error_name, args.merge(raise: true, :locale => I18n.locale))
        if translated_message.instance_of?(Hash) && translated_message.has_key?(:default)
          translated_message = I18n.translate("#{full_error_name}.default", args.merge(raise: true, :locale => I18n.locale))
        end
        translated_message
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
