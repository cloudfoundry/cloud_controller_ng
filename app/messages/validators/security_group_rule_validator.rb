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

      add_rule_error("protocol must be 'tcp', 'udp', 'icmp', or 'all'", record, index) unless valid_protocol(rule[:protocol])

      validate_destination(rule[:destination], record, index) if valid_destination_type(rule[:destination], record, index)
      validate_description(rule, record, index)
      validate_log(rule, record, index)

      case rule[:protocol]
      when 'tcp', 'udp'
        validate_tcp_udp_protocol(rule, record, index)
      when 'icmp'
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
    protocol.is_a?(String) && %w[tcp udp icmp all].include?(protocol)
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
    if destination.nil?
      error_message = 'destination must be a valid CIDR, IP address, or IP address range'
      if CloudController::RuleValidator.comma_delimited_destinations_enabled?
        error_message = 'nil destination; destination must be a comma-delimited list of valid CIDRs, IP addresses, or IP address ranges'
      end

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

    true
  end

  def validate_destination(destination, record, index)
    error_message = 'destination must be a valid CIDR, IP address, or IP address range'

    comma_delimited_destinations_enabled = CloudController::RuleValidator.comma_delimited_destinations_enabled?
    error_message = 'destination must contain valid CIDR(s), IP address(es), or IP address rang(es)' if comma_delimited_destinations_enabled

    unless destination.index(',').nil?
      unless comma_delimited_destinations_enabled
        add_rule_error(error_message, record, index)
        return
      end

      destinations = destination.partition(',')
      destination = destinations.first
      remainder = destinations.last

      validate_destination(remainder, record, index)
    end

    address_list = destination.split('-')

    if address_list.length == 1
      add_rule_error(error_message, record, index) unless CloudController::RuleValidator.parse_ip(address_list.first)

    elsif address_list.length == 2
      ipv4s = CloudController::RuleValidator.parse_ip(address_list)
      return add_rule_error('destination IP address range is invalid', record, index) unless ipv4s

      sorted_ipv4s = NetAddr.sort_IPv4(ipv4s)
      reversed_range_error = 'beginning of IP address range is numerically greater than the end of its range (range endpoints are inverted)'
      add_rule_error(reversed_range_error, record, index) unless ipv4s.first == sorted_ipv4s.first

    else
      add_rule_error(error_message, record, index)
    end
  end

  def add_rule_error(message, record, index)
    record.errors.add("Rules[#{index}]:", message)
  end
end
