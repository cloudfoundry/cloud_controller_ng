require 'messages/organization_quotas_update_message'
require 'messages/validators'
require 'messages/validators/security_group_rule_validator'

module VCAP::CloudController
  class SecurityGroupCreateMessage < BaseMessage
    MAX_SECURITY_GROUP_NAME_LENGTH = 250

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:name, :rules]

    validates_with NoAdditionalKeysValidator

    validates :name,
      presence: true,
      length: { maximum: MAX_SECURITY_GROUP_NAME_LENGTH }

    validates_with RulesValidator, if: key_requested?(:rules)
  end
end
