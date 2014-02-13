module VCAP::CloudController
  class PrivateDomainsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      to_one :owning_organization
    end

    query_parameters :name

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::DomainNameTaken.new(attributes["name"])
      else
        Errors::DomainInvalid.new(e.errors.full_messages)
      end
    end

    def self.not_found_exception_name
      :DomainNotFound
    end
  end
end
