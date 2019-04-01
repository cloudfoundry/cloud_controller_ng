require 'messages/organization_update_message'

module VCAP::CloudController
  class OrganizationCreateMessage < OrganizationUpdateMessage
    validates :name, presence: true
  end
end
