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
        ips = parse_ip(address_list)
        return false if ips.nil?

        sorted_ips = if ips.first.is_a?(NetAddr::IPv4)
                       NetAddr.sort_IPv4(ips)
                     else
                       NetAddr.sort_IPv6(ips)
                     end

        return true if ips.first == sorted_ips.first
      end

      false
    end

    def self.validate_boolean(bool)
      !!bool == bool
    end

    def self.parse_ip(val)
      ipv4 = parse_ipv4(val)

      ipv6 = parse_ipv6(val) if !ipv4 && config.get(:enable_ipv6)

      ipv4 || ipv6
    end

    def self.comma_delimited_destinations_enabled?
      config.get(:security_groups, :enable_comma_delimited_destinations)
    end

    def self.no_leading_zeros(destination)
      return no_leading_zeros_in_address(destination) unless destination.is_a?(Array)

      no_zeros = true
      destination.each do |address|
        no_zeros &&= no_leading_zeros_in_address(address)
      end

      no_zeros
    end

    private_class_method def self.config
      VCAP::CloudController::Config.config
    end

    private_class_method def self.no_leading_zeros_in_address(address)
      return no_leading_zeros_in_ipv4_address(address) if address.include?('.')

      no_leading_zeros_in_ipv6_address(address) if address.include?(':')
    end

    private_class_method def self.no_leading_zeros_in_ipv4_address(address)
      address.split('.') do |octet|
        if octet.start_with?('0') && octet.length > 1
          octet_parts = octet.split('/')
          return false if octet_parts.length < 2

          return false if octet_parts[0].length > 1 && octet_parts[0].start_with?('0')
        end
      end

      true
    end

    private_class_method def self.no_leading_zeros_in_ipv6_address(address)
      address.split(':').each do |segment|
        next unless segment.start_with?('0') && segment.length > 1

        segment_parts = segment.split('/')
        return false if segment_parts.length < 2

        return false if segment_parts[0].length > 1 && segment_parts[0].start_with?('0')
      end

      true
    end

    private_class_method def self.parse_ipv4(val)
      if val.is_a?(Array)
        val.map do |ip|
          NetAddr::IPv4.parse(ip)
        end
      else
        NetAddr::IPv4Net.parse(val)
      end
    rescue NetAddr::ValidationError
      nil
    end

    private_class_method def self.parse_ipv6(val)
      if val.is_a?(Array)
        val.map do |ip|
          NetAddr::IPv6.parse(ip)
        end
      else
        NetAddr::IPv6Net.parse(val)
      end
    rescue NetAddr::ValidationError
      nil
    end
  end
end
