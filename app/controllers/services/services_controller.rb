require 'ext/validation_error_message_overrides'

module VCAP::CloudController
  class ServicesController < RestController::ModelController
    define_attributes do
      to_many :service_plans
    end

    query_parameters :active, :label, :provider, :service_broker_guid, :unique_id

    def self.dependencies
      [:services_event_repository]
    end

    def create
      404
    end

    def update(_)
      404
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    allow_unauthenticated_access only: :enumerate
    def enumerate
      if SecurityContext.missing_token?
        @opts.delete(:inline_relations_depth)
      elsif SecurityContext.invalid_token?
        raise CloudController::Errors::ApiError.new_from_details('InvalidAuthToken')
      end

      super
    end

    def self.translate_validation_exception(e, attributes)
      CloudController::Errors::ApiError.new_from_details('ServiceInvalid', e.errors.full_messages)
    end

    def delete(guid)
      service = find_guid_and_validate_access(:delete, guid)
      if purge?
        service.purge(@services_event_repository)
        @services_event_repository.record_service_purge_event(service)
        [HTTP::NO_CONTENT, nil]
      else
        do_delete(service)
      end
    end

    define_messages
    define_routes

    private

    def purge?
      params['purge'] == 'true'
    end
  end
end
