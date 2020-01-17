require 'messages/organization_quotas_update_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < OrganizationQuotasUpdateMessage
    validates :name,
      presence: true
  end
end
