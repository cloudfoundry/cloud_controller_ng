require 'models/helpers/role_types'

module VCAP::CloudController
  SPACE_OR_ORGANIZATION_NOT_SPECIFIED = -1

  # Sequel allows to create models based on datasets. The following is a dataset that unions all the individual roles
  # tables and labels each row with a `type` column based on which table it came from
  module RoleDatasetBuilder
    def self.org_users_dataset(organization_ids=nil)
      dataset = OrganizationUser.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_USER, :type),
       Sequel.as(:role_guid, :guid),
       :user_id,
       :organization_id,
       Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
       :created_at,
       :updated_at
     )
      dataset = dataset.where(organization_id: organization_ids) if organization_ids.present?
      dataset
    end

    def self.org_managers_dataset(organization_ids=nil)
      dataset = OrganizationManager.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_MANAGER, :type),
            Sequel.as(:role_guid, :guid),
            :user_id,
            :organization_id,
            Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
            :created_at,
            :updated_at
      )
      dataset = dataset.where(organization_id: organization_ids) if organization_ids

      dataset
    end

    def self.org_billing_managers_dataset(organization_ids=nil)
      dataset = OrganizationBillingManager.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_BILLING_MANAGER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        :organization_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
        :created_at,
        :updated_at
      )
      dataset = dataset.where(organization_id: organization_ids) if organization_ids

      dataset
    end

    def self.org_auditors_dataset(organization_ids=nil)
      dataset = OrganizationAuditor.select(
        Sequel.as(VCAP::CloudController::RoleTypes::ORGANIZATION_AUDITOR, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        :organization_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id),
        :created_at,
        :updated_at
      )
      dataset = dataset.where(organization_id: organization_ids) if organization_ids
      dataset
    end

    def self.space_developers_dataset(space_ids=nil)
      dataset = SpaceDeveloper.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_DEVELOPER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at
      )
      dataset = dataset.where(space_id: space_ids) if space_ids
      dataset
    end

    def self.space_auditors_dataset(space_ids=nil)
      dataset = SpaceAuditor.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_AUDITOR, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at
      )
      dataset = dataset.where(space_id: space_ids) if space_ids
      dataset
    end

    def self.space_supporters_dataset(space_ids=nil)
      dataset = SpaceSupporter.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_SUPPORTER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at
      )
      dataset = dataset.where(space_id: space_ids) if space_ids
      dataset
    end

    def self.space_managers_dataset(space_ids=nil)
      dataset = SpaceManager.select(
        Sequel.as(VCAP::CloudController::RoleTypes::SPACE_MANAGER, :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id),
        :space_id,
        :created_at,
        :updated_at
      )
      dataset = dataset.where(space_id: space_ids) if space_ids
      dataset
    end

    def self.role_dataset(organization_id: nil, space_id: nil)
      spaces_in_org = Space.where(organization_id: organization_id).map(&:id) if organization_id
      org_users_dataset(organization_id).union(
        org_managers_dataset(organization_id),
        all: true,
        from_self: false
      ).union(
        org_billing_managers_dataset(organization_id),
        all: true,
        from_self: false
      ).union(
        org_auditors_dataset(organization_id),
        all: true,
        from_self: false
      ).union(
        space_developers_dataset(spaces_in_org),
        all: true,
        from_self: false
      ).union(
        space_auditors_dataset(spaces_in_org),
        all: true,
        from_self: false
      ).union(
        space_supporters_dataset(spaces_in_org),
        all: true,
        from_self: false
      ).union(
        space_managers_dataset(spaces_in_org),
        all: true,
        from_self: false
      ).from_self
    end
  end

  class Role < Sequel::Model(RoleDatasetBuilder.role_dataset)
    many_to_one :user, key: :user_id
    many_to_one :organization, key: :organization_id
    many_to_one :space, key: :space_id

    class << self
      def for_organization(dataset, organization_id)
        dataset.from do |o|
          RoleDatasetBuilder.role_dataset(organization_id: organization_id)
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
