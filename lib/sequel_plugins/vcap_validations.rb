module Sequel::Plugins::VcapValidations
  module InstanceMethods
    # Validates that an attribute is a valid http or https url
    #
    # @param [Symbol] The attribute to validate
    def validates_url(attr, opts={})
      return unless send(attr)

      validates_format(URI::DEFAULT_PARSER.make_regexp(%w[http https]), attr, message: opts.fetch(:message, :url))
    end
  end
end
