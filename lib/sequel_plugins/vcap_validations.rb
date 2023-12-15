module Sequel::Plugins::VcapValidations
  module InstanceMethods
    QTEXT = '[^\\x0d\\x22\\x5c\\x80-\\xff]'.freeze
    DTEXT = '[^\\x0d\\x5b-\\x5d\\x80-\\xff]'.freeze
    ATOM = '[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-' \
           '\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+'.freeze
    QUOTED_PAIR = '\\x5c[\\x00-\\x7f]'.freeze
    DOMAIN_LITERAL = "\\x5b(?:#{DTEXT}|#{QUOTED_PAIR})*\\x5d".freeze
    QUOTED_STRING = "\\x22(?:#{QTEXT}|#{QUOTED_PAIR})*\\x22".freeze
    DOMAIN_REF = ATOM
    SUB_DOMAIN = "(?:#{DOMAIN_REF}|#{DOMAIN_LITERAL})".freeze
    WORD = "(?:#{ATOM}|#{QUOTED_STRING})".freeze
    DOMAIN = "#{SUB_DOMAIN}(?:\\x2e#{SUB_DOMAIN})*".freeze
    LOCAL_PART = "#{WORD}(?:\\x2e#{WORD})*".freeze
    ADDR_SPEC = "#{LOCAL_PART}\\x40#{DOMAIN}".freeze

    EMAIL_REGEXP_WHOLE = Regexp.new("\\A#{ADDR_SPEC}\\z", Regexp::NOENCODING)
    EMAIL_REGEXP_PART = Regexp.new(ADDR_SPEC.to_s, Regexp::NOENCODING)
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
      validates_format(EMAIL_REGEXP_WHOLE, attr, message: :email) if send(attr)
    end
  end
end
