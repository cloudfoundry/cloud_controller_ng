module Sequel::Plugins::VcapValidations
  module InstanceMethods
    # Validates that an attribute is a valid http or https url
    #
    # @param [Symbol] The attribute to validate
    def validates_url(attr, opts={})
      return unless send(attr)

      validates_format(URI::DEFAULT_PARSER.make_regexp(%w[http https]), attr, message: opts.fetch(:message, :url))
    end

    # Validates that an attribute is a valid email address
    #
    # @param [Symbol] The attribute to validate
    def validates_email(attr)
      validates_format(RFC822::EMAIL_REGEXP_WHOLE, attr, message: :email) if send(attr)
    end
  end
end
