require 'models/helpers/role_types'

module VCAP::CloudController
  # creating a new model backed by a smaller union will allow us to manipulate org roles with out handling too much excess data
  class OrganizationRole < Role
    set_dataset(
      OrganizationUser.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_USER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        :organization_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
        :created_at,
        :updated_at
      ).union(
        OrganizationManager.select(
          Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
          :created_at,
          :updated_at),
          all: true,
          from_self: false
      ).union(
        OrganizationBillingManager.select(
          Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
          :created_at,
          :updated_at),
          all: true,
          from_self: false
      ).union(
        OrganizationAuditor.select(
          Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
          :created_at,
          :updated_at),
          all: true,
          from_self: false
      ).from_self
    )
  end
end
