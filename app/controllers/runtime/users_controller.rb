module VCAP::CloudController
  class UsersController < RestController::ModelController
    def self.dependencies
      [:user_event_repository, :username_populating_collection_renderer]
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
        Errors::ApiError.new_from_details('UaaIdTaken', attributes['guid'])
      else
        Errors::ApiError.new_from_details('UserInvalid', e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @collection_renderer = dependencies[:username_populating_collection_renderer]
      @user_event_repository = dependencies.fetch(:user_event_repository)
    end

    def delete(guid)
      user = find_guid_and_validate_access(:delete, guid)
      @user_event_repository.record_user_delete_request(user, SecurityContext.current_user, SecurityContext.current_user_email)
      do_delete(user)
    end

    define_messages
    define_routes
  end
end
