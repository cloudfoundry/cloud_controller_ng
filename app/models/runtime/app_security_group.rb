require 'netaddr'

module VCAP::CloudController
  class AppSecurityGroup < Sequel::Model
    APP_SECURITY_GROUP_NAME_REGEX = /\A[[[:alnum:][:punct:][:print:]]&&[^;]]+\Z/.freeze
    TRANSPORT_RULE_FIELDS = ["protocol", "port", "destination"].map(&:freeze).freeze
    ICMP_RULE_FIELDS = ["protocol", "code", "type", "destination"].map(&:freeze).freeze

    plugin :serialization

    import_attributes :name, :rules, :running_default, :staging_default, :space_guids
    export_attributes :name, :rules

    serialize_attributes :json, :rules

    many_to_many :spaces

    add_association_dependencies spaces: :nullify

    def validate
      validates_presence :name
      validates_format APP_SECURITY_GROUP_NAME_REGEX, :name
      validate_rules
    end

    def self.user_visibility_filter(user)
      Sequel.or([
                    [:spaces, user.spaces_dataset],
                    [:spaces, user.managed_spaces_dataset],
                    [:spaces, user.audited_spaces_dataset],
                    [:running_default, true],
                    [:app_security_groups_spaces__space_id, user.managed_organizations_dataset.join(:spaces, :spaces__organization_id => :organizations__id).select(:spaces__id)]
                ])
    end

    private

    def validate_rules
      return true unless rules

      unless rules.is_a?(Array) && rules.all? { |r| r.is_a?(Hash) }
        errors.add(:rules, "value must be an array of hashes. rules: '#{rules}'")
        return false
      end

      rules.each_with_index do |rule, index|
        protocol = rule['protocol']

        validation_errors = case protocol
        when "tcp", "udp"
          validate_transport_rule(rule, index)
        when "icmp"
          validate_icmp_rule(rule)
        else
          ["contains an unsupported protocol"]
        end

        validation_errors.each do |error_text|
          errors.add(:rules, "rule number #{index + 1} #{error_text}")
        end
        errors.empty?
      end
    end

    def validate_transport_rule(rule, index)
      errs = validate_fields(rule, TRANSPORT_RULE_FIELDS)
      return errs unless errs.empty?

      port = rule['port']
      unless validate_port(port)
        errs << "contains invalid port"
      end

      destination = rule['destination']
      unless validate_destination(destination)
        errs << "contains invalid destination"
      end

      errs
    end

    def validate_icmp_rule(rule)
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

    def validate_fields(rule, fields)
      errs = (fields - rule.keys).map { |field| "missing required field '#{field}'" }
      errs += (rule.keys - fields).map { |key| "contains the invalid field '#{key}'" }
    end

    def validate_port(port)
      return false if /[^\d\s\-,]/.match(port)

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

    def port_in_valid_range?(port)
      port > 0 && port < 65536
    end

    def validate_destination(destination)
      NetAddr::CIDR.create(destination)
      return true
    rescue NetAddr::ValidationError
      return false
    end

    def validate_icmp_control_message(value)
      !!(/^\-?\s*\d+\s*$/.match(value)) && value.to_i >= -1 && value.to_i < 256
    end
  end
end
