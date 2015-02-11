module VCAP::CloudController
  class PrivateDomainsController < RestController::ModelController
    def self.dependencies
      [:domain_event_repository]
    end

    define_attributes do
      attribute :name, String
      to_one :owning_organization
    end

    query_parameters :name

    def inject_dependencies(dependencies)
      super
      @domain_event_repository = dependencies.fetch(:domain_event_repository)
    end

    def delete(guid)
      domain = find_guid_and_validate_access(:delete, guid)
      @domain_event_repository.record_domain_delete_request(domain, SecurityContext.current_user, SecurityContext.current_user_email)
      do_delete(domain)
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
