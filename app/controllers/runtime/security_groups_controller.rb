module VCAP::CloudController
  class SecurityGroupsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :rules, [Hash], default: []

      to_many :spaces
    end

    query_parameters :name

    define_messages
    define_routes

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('SecurityGroupNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('SecurityGroupInvalid', e.errors.full_messages)
      end
    end
  end
end
