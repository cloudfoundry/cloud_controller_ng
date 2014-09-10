module VCAP
  module Errors
    class ApiError < StandardError
      attr_accessor :args
      attr_accessor :details
      attr_accessor :full_error_name

      def self.new_from_details(full_error_name, *args)
        # To support i18n, we use full error name in CC code. For example, in the code we change from:
        # "VCAP::Errors::ApiError.new('AppInvalid', 'instance number less than 1')"
        # to
        # "VCAP::Errors::ApiError.new('AppInvalid.InvalidInstanceNumber')"
        # 'AppInvalid.InvalidInstanceNumber' stands for the full error name, and in the i18n translation files under
        # 'vendor/errors/i18n', we will put and translate the message of this message
        name = full_error_name
        name = full_error_name[0, full_error_name.index(/\./)] unless full_error_name.index(/\./).nil?

        details = Details.new(name)
        api_error = new
        api_error.details = details
        api_error.full_error_name = full_error_name
        api_error.args = args
        api_error
      end

      def self.setup_i18n(load_path, default_locale)
        I18n.enforce_available_locales = false
        I18n.load_path = load_path
        I18n.default_locale = default_locale
        I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
        I18n.backend.reload!
      end

      def message
        formatted_args = args.map do |arg|
          (arg.is_a? Array) ? arg.map(&:to_s).join(', ') : arg.to_s
        end

        begin
          translated_message = I18n.translate(full_error_name, raise: true, :locale => I18n.locale)
          if translated_message.instance_of?(Hash) && translated_message.has_key?(:default)
            translated_message = translated_message[:default]
          end
          sprintf(translated_message, *formatted_args)
        rescue I18n::MissingTranslationData => e
          sprintf(details.message_format, *formatted_args)
        end
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


