module VCAP::CloudController
  class AppSecurityGroupsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :rules, String, default: nil
      to_many :spaces
    end

    query_parameters :name

    define_messages
    define_routes

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details("AppSecurityGroupInvalid", e.errors.full_messages)
    end
  end
end