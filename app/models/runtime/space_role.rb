require 'models/helpers/role_types'

module VCAP::CloudController
  # creating a new model backed by a smaller union will allow us to manipulate space roles with out handling too much excess data
  class SpaceRole < Role
    set_dataset(
      SpaceDeveloper.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_DEVELOPER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at,
    ).union(
      SpaceAuditor.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_AUDITOR, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at),
      all: true,
      from_self: false
    ).union(
      SpaceSupporter.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_SUPPORTER, :type),
      Sequel.as(:role_guid, :guid),
      :user_id,
      Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
      :space_id,
      :created_at,
      :updated_at),
        all: true,
        from_self: false
    ).union(
      SpaceManager.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_MANAGER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at),
      all: true,
      from_self: false
    ).from_self
  )
  end
end
