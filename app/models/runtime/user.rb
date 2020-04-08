module VCAP::CloudController
  class User < Sequel::Model
    class InvalidOrganizationRelation < CloudController::Errors::InvalidRelation
    end
    attr_accessor :username, :organization_roles, :space_roles, :origin

    no_auto_guid

    many_to_many :organizations,
      before_remove: :validate_organization_roles

    many_to_one :default_space, key: :default_space_id, class: 'VCAP::CloudController::Space'

    many_to_many :managed_organizations,
      class: 'VCAP::CloudController::Organization',
      join_table: 'organizations_managers',
      right_key: :organization_id, reciprocal: :managers,
      before_add: :validate_organization

    many_to_many :billing_managed_organizations,
      class: 'VCAP::CloudController::Organization',
      join_table: 'organizations_billing_managers',
      right_key: :organization_id,
      reciprocal: :billing_managers,
      before_add: :validate_organization

    many_to_many :audited_organizations,
      class: 'VCAP::CloudController::Organization',
      join_table: 'organizations_auditors',
      right_key: :organization_id, reciprocal: :auditors,
      before_add: :validate_organization

    many_to_many :spaces,
      class: 'VCAP::CloudController::Space',
      join_table: 'spaces_developers',
      right_key: :space_id, reciprocal: :developers

    many_to_many :managed_spaces,
      class: 'VCAP::CloudController::Space',
      join_table: 'spaces_managers',
      right_key: :space_id, reciprocal: :managers

    many_to_many :audited_spaces,
      class: 'VCAP::CloudController::Space',
      join_table: 'spaces_auditors',
      right_key: :space_id, reciprocal: :auditors

    one_to_many :labels, class: 'VCAP::CloudController::UserLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::UserAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies organizations: :nullify
    add_association_dependencies managed_organizations: :nullify
    add_association_dependencies audited_spaces: :nullify
    add_association_dependencies billing_managed_organizations: :nullify
    add_association_dependencies audited_organizations: :nullify
    add_association_dependencies spaces: :nullify
    add_association_dependencies managed_spaces: :nullify
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    export_attributes :admin, :active, :default_space_guid

    import_attributes :guid, :admin, :active,
      :organization_guids,
      :managed_organization_guids,
      :billing_managed_organization_guids,
      :audited_organization_guids,
      :space_guids,
      :managed_space_guids,
      :audited_space_guids,
      :default_space_guid

    def validate
      validates_presence :guid
      validates_unique :guid
    end

    def validate_organization(org)
      unless org && organizations.include?(org)
        raise InvalidOrganizationRelation.new("Cannot add role, user does not belong to Organization with guid #{org.guid}")
      end
    end

    def validate_organization_roles(org)
      if org && (managed_organizations.include?(org) || billing_managed_organizations.include?(org) || audited_organizations.include?(org))
        raise InvalidOrganizationRelation.new("Cannot remove user from Organization with guid #{org.guid} if the user has the OrgManager, BillingManager, or Auditor role")
      end
    end

    def export_attrs
      attrs = super
      attrs += [:username] if username
      attrs += [:organization_roles] if organization_roles
      attrs += [:space_roles] if space_roles
      attrs += [:origin] if origin
      attrs
    end

    def admin?
      raise 'This method is deprecated. A user is only an admin if their token contains the cloud_controller.admin scope'
    end

    def active?
      active
    end

    def is_oauth_client?
      is_oauth_client
    end

    def presentation_name
      username || guid
    end

    def add_managed_organization(org)
      validate_organization(org)
      OrganizationManager.find_or_create(user_id: id, organization_id: org.id)
      self.reload
    end

    def add_billing_managed_organization(org)
      validate_organization(org)
      OrganizationBillingManager.find_or_create(user_id: id, organization_id: org.id)
      self.reload
    end

    def add_audited_organization(org)
      validate_organization(org)
      OrganizationAuditor.find_or_create(user_id: id, organization_id: org.id)
      self.reload
    end

    def add_organization(org)
      OrganizationUser.find_or_create(user_id: id, organization_id: org.id)
      self.reload
    end

    def add_managed_space(space)
      SpaceManager.find_or_create(user_id: id, space_id: space.id)
      self.reload
    end

    def add_audited_space(space)
      SpaceAuditor.find_or_create(user_id: id, space_id: space.id)
      self.reload
    end

    def add_space(space)
      SpaceDeveloper.find_or_create(user_id: id, space_id: space.id)
      self.reload
    end

    def remove_spaces(space)
      remove_space space
      remove_managed_space space
      remove_audited_space space
    end

    def membership_spaces
      Space.join(:spaces_developers, space_id: :id, user_id: id).select(:spaces__id).
        union(
          Space.join(:spaces_auditors, space_id: :id, user_id: id).select(:spaces__id)
        ).
        union(
          Space.join(:spaces_managers, space_id: :id, user_id: id).select(:spaces__id)
        )
    end

    def membership_organizations
      Organization.join(:organizations_users, organization_id: :id, user_id: id).select(:organizations__id).
        union(
          Organization.join(:organizations_auditors, organization_id: :id, user_id: id).select(:organizations__id)
        ).
        union(
          Organization.join(:organizations_managers, organization_id: :id, user_id: id).select(:organizations__id)
        ).
        union(
          Organization.join(:organizations_billing_managers, organization_id: :id, user_id: id).select(:organizations__id)
        )
    end

    def visible_users_in_my_orgs
      User.join(:organizations_users, user_id: :id).select(:id).where(organization_id: membership_organizations).
        union(
          User.join(:organizations_auditors, user_id: :id).select(:id).where(organization_id: membership_organizations)
        ).
        union(
          User.join(:organizations_managers, user_id: :id).select(:id).where(organization_id: membership_organizations)
        ).
        union(
          User.join(:organizations_billing_managers, user_id: :id).select(:id).where(organization_id: membership_organizations)
        ).
        distinct
    end

    def readable_users(can_read_globally)
      if can_read_globally
        User.dataset
      else
        readable_users = visible_users_in_my_orgs.union(User.where(id: id).select(:id))
        User.where(id: readable_users)
      end
    end

    def self.uaa_users_info(user_guids)
      uaa_client = CloudController::DependencyLocator.instance.uaa_client
      uaa_client.users_for_ids(user_guids)
    end

    def self.user_visibility_filter(_)
      full_dataset_filter
    end
  end
end
