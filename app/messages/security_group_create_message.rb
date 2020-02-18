require 'messages/organization_quotas_update_message'
require 'messages/validators'

module VCAP::CloudController
  class SecurityGroupCreateMessage < BaseMessage
    MAX_SECURITY_GROUP_NAME_LENGTH = 250

    register_allowed_keys [:name]

    validates :name,
      presence: true,
      length: { maximum: MAX_SECURITY_GROUP_NAME_LENGTH }

    validates_with NoAdditionalKeysValidator
  end
end
