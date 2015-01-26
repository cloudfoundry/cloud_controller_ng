module VCAP::CloudController
  class PrivateDomainsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      to_one :owning_organization
      to_many :shared_organizations, link_only: true, exclude_in: [:create, :update], route_for: :get
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
        Errors::ApiError.new_from_details('DomainNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('DomainInvalid', e.errors.full_messages)
      end
    end

    def self.not_found_exception_name
      :DomainNotFound
    end
  end
end
