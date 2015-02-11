module VCAP::CloudController
  class QuotaDefinitionsController < RestController::ModelController
    def self.dependencies
      [:quota_definition_event_repository]
    end

    define_attributes do
      attribute :name,                       String
      attribute :non_basic_services_allowed, Message::Boolean
      attribute :total_services,             Integer
      attribute :total_routes,               Integer
      attribute :memory_limit,               Integer
      attribute :instance_memory_limit,      Integer, optional_in: :create, default: -1
    end

    query_parameters :name

    def self.translate_validation_exception(quota_definition, attributes)
      name_errors = quota_definition.errors.on(:name)
      memory_limit_errors = quota_definition.errors.on(:memory_limit)
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('QuotaDefinitionNameTaken', attributes['name'])
      elsif memory_limit_errors && memory_limit_errors.include?(:less_than_zero)
        Errors::ApiError.new_from_details('QuotaDefinitionMemoryLimitNegative')
      else
        Errors::ApiError.new_from_details('QuotaDefinitionInvalid', quota_definition.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @quota_definition_event_repository = dependencies.fetch(:quota_definition_event_repository)
    end

    def delete(guid)
      quota_definition = find_guid_and_validate_access(:delete, guid)
      @quota_definition_event_repository.record_quota_definition_delete_request(
        quota_definition,
        SecurityContext.current_user,
        SecurityContext.current_user_email)
      do_delete(quota_definition)
    end

    define_messages
    define_routes
  end
end
