module VCAP::CloudController
  class UsersController < RestController::ModelController
    def self.dependencies
      [:username_populating_collection_renderer, :username_populating_object_renderer, :user_event_repository]
    end

    define_attributes do
      attribute :guid, String, exclude_in: :update
      attribute :admin, Message::Boolean, default: false
      to_many :spaces
      to_many :organizations
      to_many :managed_organizations
      to_many :billing_managed_organizations
      to_many :audited_organizations
      to_many :managed_spaces
      to_many :audited_spaces
      to_one :default_space, optional_in: [:create]
    end

    query_parameters :space_guid, :organization_guid,
      :managed_organization_guid,
      :billing_managed_organization_guid,
      :audited_organization_guid,
      :managed_space_guid,
      :audited_space_guid

    def self.translate_validation_exception(e, attributes)
      guid_errors = e.errors.on(:guid)
      if guid_errors && guid_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('UaaIdTaken', attributes['guid'])
      else
        CloudController::Errors::ApiError.new_from_details('UserInvalid', e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def inject_dependencies(dependencies)
      super
      @object_renderer = dependencies[:username_populating_object_renderer]
      @collection_renderer = dependencies[:username_populating_collection_renderer]
      @user_event_repository = dependencies.fetch(:user_event_repository)
    end

    delete "#{path_guid}/spaces/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :developers, id, Space)
    end

    delete "#{path_guid}/managed_spaces/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :managers, id, Space)
    end

    delete "#{path_guid}/audited_spaces/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :auditors, id, Space)
    end

    delete "#{path_guid}/organizations/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :users, id, Organization)
    end

    delete "#{path_guid}/managed_organizations/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :managers, id, Organization)
    end

    delete "#{path_guid}/billing_managed_organizations/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :billing_managers, id, Organization)
    end

    delete "#{path_guid}/audited_organizations/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :auditors, id, Organization)
    end

    put "#{path_guid}/audited_spaces/:space_guid" do |api, id, space_guid|
      api.dispatch(:add_space_role, id, :audited_spaces, space_guid)
    end

    put "#{path_guid}/managed_spaces/:space_guid" do |api, id, space_guid|
      api.dispatch(:add_space_role, id, :managed_spaces, space_guid)
    end

    put "#{path_guid}/spaces/:space_guid" do |api, id, space_guid|
      api.dispatch(:add_space_role, id, :spaces, space_guid)
    end

    put "#{path_guid}/organizations/:org_guid" do |api, id, org_guid|
      api.dispatch(:add_organization_role, id, :organizations, org_guid)
    end

    put "#{path_guid}/audited_organizations/:org_guid" do |api, id, org_guid|
      api.dispatch(:add_organization_role, id, :audited_organizations, org_guid)
    end

    put "#{path_guid}/managed_organizations/:org_guid" do |api, id, org_guid|
      api.dispatch(:add_organization_role, id, :managed_organizations, org_guid)
    end

    put "#{path_guid}/billing_managed_organizations/:org_guid" do |api, id, org_guid|
      api.dispatch(:add_organization_role, id, :billing_managed_organizations, org_guid)
    end

    define_messages
    define_routes

    # related_guid should map back to other_id
    def remove_related(related_guid, name, user_guid, find_model=model)
      response = super(related_guid, name, user_guid, find_model)
      user = User.first(guid: user_guid)
      user.username = '' unless user.username

      if find_model == Space
        @user_event_repository.record_space_role_remove(
          Space.first(guid: related_guid),
          user,
          name.to_s.singularize,
          UserAuditInfo.from_context(SecurityContext),
          {})
      elsif find_model == Organization
        @user_event_repository.record_organization_role_remove(
          Organization.first(guid: related_guid),
          user,
          name.to_s.singularize,
          UserAuditInfo.from_context(SecurityContext),
          {})
      end

      response
    end

    def add_space_role(user_guid, relationship, space_guid)
      response = add_related(user_guid, relationship, space_guid, User)
      user = User.first(guid: user_guid)
      user.username = ''

      role = if relationship.eql?(:audited_spaces)
               'auditor'
             elsif relationship.eql?(:managed_spaces)
               'manager'
             else
               'developer'
             end

      @user_event_repository.record_space_role_add(Space.first(guid: space_guid), user, role, UserAuditInfo.from_context(SecurityContext))

      response
    end

    def add_organization_role(user_guid, relationship, org_guid)
      response = add_related(user_guid, relationship, org_guid, User)
      user = User.first(guid: user_guid)
      user.username = ''

      role = if relationship.eql?(:billing_managed_organizations)
               'billing_manager'
             elsif relationship.eql?(:audited_organizations)
               'auditor'
             elsif relationship.eql?(:managed_organizations)
               'manager'
             else
               'user'
             end

      @user_event_repository.record_organization_role_add(Organization.first(guid: org_guid), user, role, UserAuditInfo.from_context(SecurityContext))

      response
    end
  end
end
