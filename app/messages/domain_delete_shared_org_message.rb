require 'messages/base_message'

module VCAP::CloudController
  class DomainDeleteSharedOrgMessage < BaseMessage
    register_allowed_keys [:guid, :org_guid]

    validates_with NoAdditionalKeysValidator

    validates :guid, presence: true, string: true
    validates :org_guid, presence: true, string: true
  end
end
