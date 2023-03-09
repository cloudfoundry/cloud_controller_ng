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
    many_to_many :staging_spaces,
      class: 'VCAP::CloudController::Space',
      join_table: 'staging_security_groups_spaces',
      right_key: :staging_space_id,
      left_key: :staging_security_group_id

    add_association_dependencies spaces: :nullify, staging_spaces: :nullify

    def validate
      validates_presence :name
      validates_unique :name
      validates_format SECURITY_GROUP_NAME_REGEX, :name
      validate_rules_length
      validate_rules
    end

    def self.user_visibility_filter(user)
      visible_space_ids = user.space_developer_space_ids.
                          union(user.space_manager_space_ids, from_self: false).
                          union(user.space_auditor_space_ids, from_self: false).
                          union(user.space_supporter_space_ids, from_self: false).
                          union(Space.join(user.org_manager_org_ids, organization_id: :organization_id).select(:spaces__id), from_self: false)

      Sequel.or([
        [:running_default, true],
        [:staging_default, true],
        [:id, SecurityGroupsSpace.where(space_id: visible_space_ids).select(:security_group_id).
                union(StagingSecurityGroupsSpace.where(staging_space_id: visible_space_ids).select(:staging_security_group_id), from_self: false)]
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
        stringified_rule = rule.stringify_keys
        protocol = stringified_rule['protocol']

        validation_errors = case protocol
                            when 'tcp', 'udp'
                              CloudController::TransportRuleValidator.validate(stringified_rule)
                            when 'icmp'
                              CloudController::ICMPRuleValidator.validate(stringified_rule)
                            when 'all'
                              CloudController::RuleValidator.validate(stringified_rule)
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
