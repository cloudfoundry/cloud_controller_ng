require 'netaddr'

module VCAP::CloudController
  class SecurityGroup < Sequel::Model
    SECURITY_GROUP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/
    MAX_RULES_CHAR_LENGTH = 2**24 - 1

    plugin :serialization

    import_attributes :name, :rules, :running_default, :staging_default, :space_guids
    export_attributes :name, :rules, :running_default, :staging_default

    serialize_attributes :json, :rules

    many_to_many :spaces

    add_association_dependencies spaces: :nullify

    def validate
      validates_presence :name
      validates_unique :name
      validates_format SECURITY_GROUP_NAME_REGEX, :name
      validate_rules_length
      validate_rules
    end

    def self.user_visibility_filter(user)
      Sequel.or([
        [:spaces, user.spaces_dataset],
        [:spaces, user.managed_spaces_dataset],
        [:spaces, user.audited_spaces_dataset],
        [:running_default, true],
        [:spaces, Space.where(space_id:
                              user.managed_organizations_dataset.
                              join(:spaces, spaces__organization_id: :organizations__id).
                              select(:spaces__id))]
      ])
    end

    private

    def validate_rules_length
      return if self[:rules].nil?

      # use this instead of validates_max_length b/c we care about the serialized
      # value that is happening due to our use of the serialize_attributes on rules column
      if self[:rules].length > MAX_RULES_CHAR_LENGTH
        errors.add(:rules, "length must not exceed #{MAX_RULES_CHAR_LENGTH} characters")
      end
    end

    def validate_rules
      return true unless rules

      unless rules.is_a?(Array) && rules.all? { |r| r.is_a?(Hash) }
        errors.add(:rules, "value must be an array of hashes. rules: '#{rules}'")
        return false
      end

      rules.each_with_index do |rule, index|
        protocol = rule['protocol']

        validation_errors = case protocol
                            when 'tcp', 'udp'
                              CloudController::TransportRuleValidator.validate(rule)
                            when 'icmp'
                              CloudController::ICMPRuleValidator.validate(rule)
                            when 'all'
                              CloudController::RuleValidator.validate(rule)
                            else
                              ['contains an unsupported protocol']
                            end

        validation_errors.each do |error_text|
          errors.add(:rules, "rule number #{index + 1} #{error_text}")
        end
        errors.empty?
      end
    end
  end
end
