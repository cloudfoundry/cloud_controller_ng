module CloudController
  class TransportRuleValidator < RuleValidator
    self.required_fields += ['ports']

    def self.validate(rule)
      errs = super
      return errs unless errs.empty?

      errs << 'contains invalid ports' unless validate_port(rule['ports'])

      errs
    end

    def self.validate_port(port)
      return false if /[^\d\s\-,]/.match?(port)

      port_range = /\A\s*(\d+)\s*-\s*(\d+)\s*\z/.match(port)
      if port_range
        left = port_range.captures[0].to_i
        right = port_range.captures[1].to_i

        return false if left >= right
        return false unless port_in_valid_range?(left) && port_in_valid_range?(right)

        return true
      end

      port_list = port.split(',')
      unless port_list.empty?
        return false unless port_list.all? { |p| /\A\s*\d+\s*\z/.match(p) }
        return false unless port_list.all? { |p| port_in_valid_range?(p.to_i) }

        return true
      end

      false
    end

    def self.port_in_valid_range?(port)
      port > 0 && port < 65_536
    end
  end
end
