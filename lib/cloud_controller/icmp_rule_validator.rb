module CloudController
  class ICMPRuleValidator < RuleValidator
    self.required_fields += %w[code type]

    def self.validate(rule)
      errs = super
      return errs unless errs.empty?

      icmp_type = rule['type']
      errs << 'contains invalid type' unless validate_icmp_control_message(icmp_type)

      icmp_code = rule['code']
      errs << 'contains invalid code' unless validate_icmp_control_message(icmp_code)

      errs
    end

    def self.validate_icmp_control_message(value)
      value.is_a?(Integer) && value >= -1 && value < 256
    end
  end
end
