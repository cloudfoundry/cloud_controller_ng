module CloudController
  class RuleValidator
    class_attribute :required_fields, :optional_fields

    self.required_fields = ['protocol', 'destination']
    self.optional_fields = ['log', 'description']

    def self.validate(rule)
      errs = validate_fields(rule)
      return errs unless errs.empty?

      destination = rule['destination']
      unless validate_destination(destination)
        errs << 'contains invalid destination'
      end

      if rule.key?('log') && !validate_boolean(rule['log'])
        errs << 'contains invalid log value'
      end

      if rule.key?('description') && !rule['description'].is_a?(String)
        errs << 'contains invalid description'
      end

      errs
    end

    def self.validate_fields(rule)
      (required_fields - rule.keys).map { |field| "missing required field '#{field}'" } +
        (rule.keys - (required_fields + optional_fields)).map { |key| "contains the invalid field '#{key}'" }
    end

    def self.validate_destination(destination)
      return false if destination.empty? || /\s/ =~ destination

      address_list = destination.split('-')

      return false if address_list.length > 2

      if address_list.length == 1
        NetAddr::IPv4Net.parse(address_list.first)
        return true
      end

      ipv4s = address_list.map do |address|
        NetAddr::IPv4.parse(address)
      end
      sorted_ipv4s = NetAddr.sort_IPv4(ipv4s)
      return true if ipv4s.first == sorted_ipv4s.first

      false
    rescue NetAddr::ValidationError
      false
    end

    def self.validate_boolean(bool)
      !!bool == bool
    end
  end
end
