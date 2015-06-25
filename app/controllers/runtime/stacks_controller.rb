module VCAP::CloudController
  class StacksController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :description, String, default: nil
    end

    query_parameters :name

    get path, :enumerate
    get path_guid, :read
    delete path_guid, :delete
    post path, :create

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('StackNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('StackInvalid', e.errors.full_messages)
      end
    end

    def delete(guid)
      obj = find_guid_and_validate_access(:delete, guid)
      do_delete(obj)
    end

    define_messages
  end
end
