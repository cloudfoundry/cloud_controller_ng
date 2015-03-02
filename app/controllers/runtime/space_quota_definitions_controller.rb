module VCAP::CloudController
  class SpaceQuotaDefinitionsController < RestController::ModelController
    def self.dependencies
      [:space_quota_definition_event_repository]
    end

    define_attributes do
      attribute :name,                       String
      attribute :non_basic_services_allowed, Message::Boolean
      attribute :total_services,             Integer
      attribute :total_routes,               Integer
      attribute :memory_limit,               Integer
      attribute :instance_memory_limit,      Integer, default: nil

      to_one :organization
      to_many :spaces, exclude_in: [:create, :update]
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('SpaceQuotaDefinitionNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('SpaceQuotaDefinitionInvalid', e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @space_quota_definition_event_repository = dependencies.fetch(:space_quota_definition_event_repository)
    end

    def delete(guid)
      space_quota_definition = find_guid_and_validate_access(:delete, guid)
      @space_quota_definition_event_repository.record_space_quota_definition_delete_request(
        space_quota_definition,
        SecurityContext.current_user,
        SecurityContext.current_user_email)
      do_delete(space_quota_definition)
    end

    define_messages
    define_routes
  end
end
