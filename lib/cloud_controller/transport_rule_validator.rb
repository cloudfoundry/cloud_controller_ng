module CloudController
  class TransportRuleValidator < RuleValidator
    self.required_fields += ['ports']

    def self.validate(rule)
      errs = super
      return errs unless errs.empty?

      unless validate_port(rule['ports'])
        errs << 'contains invalid ports'
      end

      errs
    end

    def self.validate_port(port)
      return false if /[^\d\s\-,]/ =~ port

      port_range = /^\s*(\d+)\s*-\s*(\d+)\s*$/.match(port)
      if port_range
        left = port_range.captures[0].to_i
        right = port_range.captures[1].to_i

        return false if left >= right
        return false unless port_in_valid_range?(left) && port_in_valid_range?(right)

        return true
      end

      port_list = port.split(',')
      if port_list.length > 0
        return false unless port_list.all? { |p| /^\s*\d+\s*$/.match(p) }
        return false unless port_list.all? { |p| port_in_valid_range?(p.to_i) }

        return true
      end

      false
    end

    def self.port_in_valid_range?(port)
      port > 0 && port < 65536
    end
  end
end
