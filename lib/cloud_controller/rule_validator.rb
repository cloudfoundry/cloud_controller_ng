module CloudController
  class RuleValidator
    class_attribute :required_fields, :optional_fields

    self.required_fields = %w[protocol destination]
    self.optional_fields = %w[log description]

    def self.validate(rule)
      errs = validate_fields(rule)
      return errs unless errs.empty?

      destination = rule['destination']
      errs << 'contains invalid destination' unless validate_destination_type(destination) && validate_destination(destination)

      errs << 'contains invalid log value' if rule.key?('log') && !validate_boolean(rule['log'])

      errs << 'contains invalid description' if rule.key?('description') && !rule['description'].is_a?(String)

      errs
    end

    def self.validate_fields(rule)
      (required_fields - rule.keys).map { |field| "missing required field '#{field}'" } +
        (rule.keys - (required_fields + optional_fields)).map { |key| "contains the invalid field '#{key}'" }
    end

    def self.validate_destination_type(destination)
      return false if destination.empty?

      return false unless destination.is_a?(String)

      return false if /\s/ =~ destination

      true
    end

    def self.validate_destination(destination)
      unless destination.index(',').nil?
        return false unless comma_delimited_destinations_enabled?

        destinations = destination.partition(',')
        first_destination = destinations.first
        remainder = destinations.last
        return validate_destination(first_destination) && validate_destination(remainder)
      end

      address_list = destination.split('-')

      if address_list.length == 1
        return true if parse_ip(address_list.first)

      elsif address_list.length == 2
        ipv4s = parse_ip(address_list)
        return false if ipv4s.nil?

        sorted_ipv4s = NetAddr.sort_IPv4(ipv4s)
        return true if ipv4s.first == sorted_ipv4s.first
      end

      false
    end

    def self.validate_boolean(bool)
      !!bool == bool
    end

    def self.parse_ip(val)
      if val.is_a?(Array)
        val.map { |ip| NetAddr::IPv4.parse(ip) }
      else
        NetAddr::IPv4Net.parse(val)
      end
    rescue NetAddr::ValidationError
      nil
    end

    def self.comma_delimited_destinations_enabled?
      config = VCAP::CloudController::Config.config
      config.get(:security_groups, :enable_comma_delimited_destinations)
    end
  end
end
