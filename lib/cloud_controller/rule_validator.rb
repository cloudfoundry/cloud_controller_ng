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
      return false if destination.empty?
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

    def self.validate_boolean(bool)
      !!bool == bool
    end
  end
end
