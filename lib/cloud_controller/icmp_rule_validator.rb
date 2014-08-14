module CloudController
  class ICMPRuleValidator < RuleValidator
    self.required_fields += ["code", "type"]

    def self.validate(rule)
      errs = super
      return errs unless errs.empty?

      icmp_type = rule['type']
      unless validate_icmp_control_message(icmp_type)
        errs << "contains invalid type"
      end

      icmp_code = rule['code']
      unless validate_icmp_control_message(icmp_code)
        errs << "contains invalid code"
      end

      errs
    end

    private

    def self.validate_icmp_control_message(value)
      value.is_a?(Integer) && value >= -1 && value < 256
    end
  end
end
