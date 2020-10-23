require 'active_model'

class RulesValidator < ActiveModel::Validator
  ALLOWED_RULE_KEYS = [
    :code,
    :description,
    :destination,
    :log,
    :ports,
    :protocol,
    :type,
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
    protocol.is_a?(String) && %w(tcp udp icmp all).include?(protocol)
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

    unless valid_ports(rule[:ports])
      add_rule_error('ports must be a valid single port, comma separated list of ports, or range or ports, formatted as a string', record, index)
    end
  end

  def validate_icmp_protocol(rule, record, index)
    add_rule_error('code is required for protocols of type ICMP', record, index) unless rule[:code]
    add_rule_error('code must be an integer between -1 and 255 (inclusive)', record, index) unless valid_icmp_format(rule[:code])

    add_rule_error('type is required for protocols of type ICMP', record, index) unless rule[:type]
    add_rule_error('type must be an integer between -1 and 255 (inclusive)', record, index) unless valid_icmp_format(rule[:type])
  end

  def valid_icmp_format(field)
    field.is_a?(Integer) && field >= -1 && field <= 255
  end

  def valid_ports(ports)
    return false unless ports.is_a?(String)
    return false if /[^\d\s\-,]/.match?(ports)

    port_range = /\A\s*(\d+)\s*-\s*(\d+)\s*\z/.match(ports)
    if port_range
      left = port_range.captures[0].to_i
      right = port_range.captures[1].to_i

      return false if left >= right
      return false unless port_in_range(left) && port_in_range(right)

      return true
    end

    port_list = ports.split(',')
    if !port_list.empty?
      return false unless port_list.all? { |p| /\A\s*\d+\s*\z/.match(p) }
      return false unless port_list.all? { |p| port_in_range(p.to_i) }

      return true
    end

    false
  end

  def port_in_range(port)
    port > 0 && port < 65536
  end

  def valid_destination_type(destination, record, index)
    if destination.nil?
      add_rule_error('destination must be a valid CIDR, IP address, or IP address range', record, index)
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
    address_list = destination.split('-')
    error_message = 'destination must be a valid CIDR, IP address, or IP address range'

    if address_list.length == 1
      add_rule_error(error_message, record, index) unless parse_ip(address_list.first)

    elsif address_list.length == 2
      ipv4s = parse_ip(address_list)
      return add_rule_error(error_message, record, index) unless ipv4s

      sorted_ipv4s = NetAddr.sort_IPv4(ipv4s)
      add_rule_error(error_message, record, index) unless ipv4s.first == sorted_ipv4s.first

    else
      add_rule_error(error_message, record, index)
    end
  end

  def parse_ip(val)
    if val.is_a?(Array)
      val.map { |ip| NetAddr::IPv4.parse(ip) }
    else
      NetAddr::IPv4Net.parse(val)
    end
  rescue NetAddr::ValidationError
    return nil
  end

  def add_rule_error(message, record, index)
    record.errors.add("Rules[#{index}]:", message)
  end
end
