require 'active_model'

class RulesValidator < ActiveModel::Validator
  ALLOWED_RULE_KEYS = %i[
    code
    description
    destination
    log
    ports
    protocol
    type
  ].freeze

  MAX_DESTINATIONS_PER_RULE = 6000

  def validate(record)
    unless record.rules.is_a?(Array)
      record.errors.add :rules, 'must be an array'
      return
    end

    record.rules.each_with_index do |rule, index|
      unless rule.is_a?(Hash)
        add_rule_error('must be an object', record, index)
        next
      end

      validate_allowed_keys(rule, record, index)

      add_rule_error("protocol must be 'tcp', 'udp', 'icmp', 'icmpv6' or 'all'", record, index) unless valid_protocol(rule[:protocol])

      if rule[:protocol] == 'icmp'
        allowed_ip_version = NetAddr::IPv4Net
      elsif rule[:protocol] == 'icmpv6'
        allowed_ip_version = NetAddr::IPv6Net
      else
        allowed_ip_version = nil
      end

      if valid_destination_type(rule[:destination], record, index)
        destinations = rule[:destination].split(',', -1)
        add_rule_error("maximum destinations per rule exceeded - must be under #{MAX_DESTINATIONS_PER_RULE}", record, index) unless destinations.length <= MAX_DESTINATIONS_PER_RULE

        destinations.each do |d|
          validate_destination(d, rule[:protocol], allowed_ip_version, record, index)
        end
      end

      validate_description(rule, record, index)
      validate_log(rule, record, index)

      case rule[:protocol]
      when 'tcp', 'udp'
        validate_tcp_udp_protocol(rule, record, index)
      when 'icmp'
        validate_icmp_protocol(rule, record, index)
      when 'icmpv6'
        add_rule_error("icmpv6 cannot be used if enable_ipv6 is false", record, index) unless CloudController::RuleValidator.ipv6_enabled?
        validate_icmp_protocol(rule, record, index)
      when 'all'
        add_rule_error('ports are not allowed for protocols of type all', record, index) if rule[:ports]
      end
    end
  end

  def boolean?(value)
    [true, false].include? value
  end

  def valid_protocol(protocol)
    protocol.is_a?(String) && %w[tcp udp icmp icmpv6 all].include?(protocol)
  end

  def validate_allowed_keys(rule, record, index)
    invalid_keys = rule.keys - ALLOWED_RULE_KEYS
    add_rule_error("unknown field(s): #{invalid_keys.map(&:to_s)}", record, index) if invalid_keys.any?
  end

  def validate_description(rule, record, index)
    add_rule_error('description must be a string', record, index) if rule[:description] && !rule[:description].is_a?(String)
  end

  def validate_log(rule, record, index)
    add_rule_error('log must be a boolean', record, index) if rule[:log] && !boolean?(rule[:log])
  end

  def validate_tcp_udp_protocol(rule, record, index)
    add_rule_error('ports are required for protocols of type TCP and UDP', record, index) unless rule[:ports]

    return if valid_ports(rule[:ports])

    add_rule_error('ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string', record, index)
  end

  def validate_icmp_protocol(rule, record, index)
    add_rule_error('code is required for protocols of type ICMP', record, index) unless rule[:code]
    add_rule_error('code must be an integer between -1 and 255 (inclusive)', record, index) unless valid_icmp_format(rule[:code])

    add_rule_error('type is required for protocols of type ICMP', record, index) unless rule[:type]
    add_rule_error('type must be an integer between -1 and 255 (inclusive)', record, index) unless valid_icmp_format(rule[:type])
  end

  def valid_icmp_format(field)
    CloudController::ICMPRuleValidator.validate_icmp_control_message(field)
  end

  def valid_ports(ports)
    return false unless ports.is_a?(String)

    CloudController::TransportRuleValidator.validate_port(ports)
  end

  def valid_destination_type(destination, record, index)
    error_message = 'destination must be a valid CIDR, IP address, or IP address range'
    if CloudController::RuleValidator.comma_delimited_destinations_enabled?
      error_message = 'nil destination; destination must be a comma-delimited list of valid CIDRs, IP addresses, or IP address ranges'
    end

    if destination.nil?
      add_rule_error(error_message, record, index)
      return false
    end

    unless destination.is_a?(String)
      add_rule_error('destination must be a string', record, index)
      return false
    end

    if /\s/ =~ destination
      add_rule_error('destination must not contain whitespace', record, index)
      return false
    end

    if !CloudController::RuleValidator.comma_delimited_destinations_enabled? && !destination.index(',').nil?
      add_rule_error(error_message, record, index)
      return false
    end

    true
  end

  def validate_destination(destination, protocol, allowed_ip_version, record, index)
    error_message = 'destination must be a valid CIDR, IP address, or IP address range'
    error_message = 'destination must contain valid CIDR(s), IP address(es), or IP address range(s)' if CloudController::RuleValidator.comma_delimited_destinations_enabled?
    add_rule_error('empty destination specified in comma-delimited list', record, index) if destination.empty?

    address_list = destination.split('-')

    zeros_error_message = 'destination octets cannot contain leading zeros'
    add_rule_error(zeros_error_message, record, index) unless CloudController::RuleValidator.no_leading_zeros(address_list)

    if address_list.length == 1
      parsed_ip = CloudController::RuleValidator.parse_ip(address_list.first)
      add_rule_error(error_message, record, index) unless parsed_ip
      add_rule_error("for protocol \"#{protocol}\" you cannot use IPv#{parsed_ip.version} addresses", record, index) unless parsed_ip.nil? || allowed_ip_version.nil? || parsed_ip.is_a?(allowed_ip_version)
    elsif address_list.length == 2
      ips = CloudController::RuleValidator.parse_ip(address_list)
      return add_rule_error('destination IP address range is invalid', record, index) unless ips

      sorted_ips = if ips.first.is_a?(NetAddr::IPv4)
                     NetAddr.sort_IPv4(ips)
                   else
                     NetAddr.sort_IPv6(ips)
                   end

      reversed_range_error = 'beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
      add_rule_error(reversed_range_error, record, index) unless ips.first == sorted_ips.first
      add_rule_error("for protocol \"#{protocol}\" you cannot use IPv#{ips.first.version} addresses", record, index) unless ips.first.nil? || allowed_ip_version.nil? || ips.first.is_a?(allowed_ip_version)

    else
      add_rule_error(error_message, record, index)
    end
  end

  def add_rule_error(message, record, index)
    record.errors.add("Rules[#{index}]:", message)
  end
end
