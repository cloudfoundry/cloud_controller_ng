module CloudController
  class ICMPRuleValidator
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

    def self.validate_fields(rule, fields)
      errs = (fields - rule.keys).map { |field| "missing required field '#{field}'" }
      errs += (rule.keys - fields).map { |key| "contains the invalid field '#{key}'" }
    end

    def self.validate_destination(destination)
      address_list = destination.split('-')

      return false if address_list.length > 2

      address_list.each do |address|
        NetAddr::CIDR.create(address)
      end

      if address_list.length > 1
        return false if NetAddr.ip_to_i(address_list[0]) > NetAddr.ip_to_i(address_list[1])
      end

      return true

    rescue NetAddr::ValidationError
      return false
    end

    def self.validate_icmp_control_message(value)
      value.is_a?(Integer) && value >= -1 && value < 256
    end
  end
end
