module VCAP::CloudController
  class OrganizationManager < Sequel::Model(:organizations_managers)
    many_to_one :user
    many_to_one :organization

    def validate
      validates_unique [:organization_id, :user_id]
      validates_presence :organization_id
      validates_presence :user_id
    end

    def type
      @type ||= RoleTypes::ORGANIZATION_MANAGER
    end
  end
end
