module CloudController
  class ICMPRuleValidator < RuleValidator
    ICMP_RULE_FIELDS = ["protocol", "code", "type", "destination"].map(&:freeze).freeze

    def self.validate(rule)
      errs = validate_fields(rule, ICMP_RULE_FIELDS)
      return errs unless errs.empty?

      icmp_type = rule['type']
      unless validate_icmp_control_message(icmp_type)
        errs << "contains invalid type"
      end

      icmp_code = rule['code']
      unless validate_icmp_control_message(icmp_code)
        errs << "contains invalid code"
      end

      destination = rule['destination']
      unless validate_destination(destination)
        errs << "contains invalid destination"
      end

      errs
    end

    private

    def self.validate_icmp_control_message(value)
      value.is_a?(Integer) && value >= -1 && value < 256
    end
  end
end
