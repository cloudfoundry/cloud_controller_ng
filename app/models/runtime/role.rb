require 'models/helpers/role_types'

module VCAP::CloudController
  SPACE_OR_ORGANIZATION_NOT_SPECIFIED = -1

  # Sequel allows to create models based on datasets. The following is a dataset that unions all the individual roles
  # tables and labels each row with a `type` column based on which table it came from

  def self.role_dataset(organization_id=false)
    if organization_id
      spaces_in_org = Space.where(organization_id: organization_id).map(&:id)
      OrganizationUser.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_USER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        :organization_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
        :created_at,
        :updated_at
      ).where(organization_id: organization_id).union(
        OrganizationManager.select(
          Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
          :created_at,
          :updated_at).where(organization_id: organization_id),
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
          :updated_at).where(organization_id: organization_id),
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
          :updated_at).where(organization_id: organization_id),
        all: true,
        from_self: false
      ).union(
        SpaceDeveloper.select(
          Sequel.as(VCAP::CloudController::RoleTypes::SPACE_DEVELOPER, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
          :space_id,
          :created_at,
          :updated_at).where(space_id: spaces_in_org),
          all: true,
          from_self: false
      ).union(
        SpaceAuditor.select(
          Sequel.as(VCAP::CloudController::RoleTypes::SPACE_AUDITOR, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
          :space_id,
          :created_at,
          :updated_at).where(space_id: spaces_in_org),
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
          :updated_at).where(space_id: spaces_in_org),
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
          :updated_at).where(space_id: spaces_in_org),
          all: true,
          from_self: false
      ).from_self
    else
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
      ).union(
        SpaceDeveloper.select(
          Sequel.as(VCAP::CloudController::RoleTypes::SPACE_DEVELOPER, :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
          :space_id,
          :created_at,
          :updated_at),
          all: true,
          from_self: false
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
    end
  end

  class Role < Sequel::Model(role_dataset)
    many_to_one :user, key: :user_id
    many_to_one :organization, key: :organization_id
    many_to_one :space, key: :space_id

    class << self
      def for_organization(organization_id)
        self.from do |o|
          VCAP::CloudController.role_dataset(organization_id)
        end
      end
    end

    def user_guid
      user.guid
    end

    def organization_guid
      return organization.guid unless organization_id == SPACE_OR_ORGANIZATION_NOT_SPECIFIED

      space.organization_guid
    end

    def space_guid
      space.guid unless space_id == SPACE_OR_ORGANIZATION_NOT_SPECIFIED
    end

    def for_space?
      VCAP::CloudController::RoleTypes::SPACE_ROLES.include?(type)
    end

    def model_class
      case type
      when VCAP::CloudController::RoleTypes::SPACE_MANAGER
        SpaceManager
      when VCAP::CloudController::RoleTypes::SPACE_AUDITOR
        SpaceAuditor
      when VCAP::CloudController::RoleTypes::SPACE_DEVELOPER
        SpaceDeveloper
      when VCAP::CloudController::RoleTypes::SPACE_SUPPORTER
        SpaceSupporter
      when VCAP::CloudController::RoleTypes::ORGANIZATION_USER
        OrganizationUser
      when VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR
        OrganizationAuditor
      when VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER
        OrganizationBillingManager
      when VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER
        OrganizationManager
      else
        raise Error.new("Invalid role type: #{type}")
      end
    end
  end
end
