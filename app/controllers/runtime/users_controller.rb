module VCAP::CloudController
  class UsersController < RestController::ModelController
    def self.dependencies
      [:username_populating_collection_renderer, :user_event_repository]
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
      @collection_renderer = dependencies[:username_populating_collection_renderer]
      @user_event_repository = dependencies.fetch(:user_event_repository)
    end

    delete "#{path_guid}/spaces/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :developers, id, Space)
    end

    delete "#{path_guid}/managed_spaces/:other_id" do |api, id, other_id|
      api.dispatch(:remove_related, other_id, :managers, id, Space)
    end

    # delete "/v2/users/:user_guid/audited_spaces/:space_guid", :delete_audited_space
    # other_id is guid of space, id is user
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

    define_messages
    define_routes

    # related_guid should map back to other_id
    def remove_related(related_guid, name, user_guid, find_model=model)
      response = super(related_guid, name, user_guid, find_model)
      user = User.first(guid: user_guid)
      user.username = ''

      if find_model == Space
        @user_event_repository.record_space_role_remove(Space.first(guid: related_guid), user, name.to_s.singularize, SecurityContext.current_user, SecurityContext.current_user_email, {})
      end

      response
    end

    private

    def delete_audited_space(user_guid, space_guid)
      delete_space_role(user_guid, space_guid, :auditor)
    end

    def delete_space_role(user_guid, space_guid, role)
      self.class.api.dispatch(:remove_related, space_guid, role, user_guid, Space)
      user = User.first(guid: id)
      @user_event_repository.record_space_role_remove(Space.first(guid: other_id), user, 'auditor', SecurityContext.current_user, SecurityContext.current_user_email, {})
    end
  end
end
