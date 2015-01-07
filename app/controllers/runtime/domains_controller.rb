module VCAP::CloudController
  class DomainsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :wildcard, Message::Boolean, default: true
      to_one :owning_organization, optional_in: :create
      to_many :spaces
    end

    query_parameters :name, :owning_organization_guid, :space_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('DomainNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('DomainInvalid', e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    deprecated_endpoint(path)
    define_messages
    define_routes
  end
end
