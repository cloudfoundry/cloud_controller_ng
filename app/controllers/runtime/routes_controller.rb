module VCAP::CloudController
  class RoutesController < RestController::ModelController
    define_attributes do
      attribute :host, String, :default => ""
      to_one :domain
      to_one :space
      to_many :apps
    end

    query_parameters :host, :domain_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        return Errors::ApiError.new_from_details("RouteHostTaken", attributes["host"])
      end

      space_errors = e.errors.on(:space)
      if space_errors && space_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details("SpaceQuotaTotalRoutesExceeded")
      end

      org_errors = e.errors.on(:organization)
      if org_errors && org_errors.include?(:total_routes_exceeded)
        return Errors::ApiError.new_from_details("OrgQuotaTotalRoutesExceeded")
      end

      Errors::ApiError.new_from_details("RouteInvalid", e.errors.full_messages)
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes

    private

    def before_create
      return if SecurityContext.admin?
      FeatureFlag.raise_unless_enabled!('route_creation')
    end
  end
end
