module VCAP::CloudController
  class SecurityGroupsController < RestController::ModelController
    def self.dependencies
      [:security_group_event_repository]
    end

    define_attributes do
      attribute :name, String
      attribute :rules, [Hash], default: []

      to_many :spaces
    end

    query_parameters :name

    define_messages
    define_routes

    def inject_dependencies(dependencies)
      super
      @security_group_event_repository = dependencies.fetch(:security_group_event_repository)
    end

    def delete(guid)
      security_group = find_guid_and_validate_access(:delete, guid)
      @security_group_event_repository.record_security_group_delete_request(
        security_group,
        SecurityContext.current_user,
        SecurityContext.current_user_email)
      do_delete(security_group)
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('SecurityGroupNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('SecurityGroupInvalid', e.errors.full_messages)
      end
    end
  end
end
