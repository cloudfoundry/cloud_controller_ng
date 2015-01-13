module VCAP::CloudController
  class BillingEventsController < RestController::ModelController
    def self.dependencies
      [:entity_only_paginated_collection_renderer]
    end

    # override base enumeration functionality.  This is mainly becase we need
    # better controll over the dataset returned, and we don't have generic
    # functionality for the controller to configure its dataset.
    def enumerate
      raise Errors::ApiError.new_from_details('NotAuthenticated') unless user

      unless start_time && end_time
        raise Errors::ApiError.new_from_details('BillingEventQueryInvalid')
      end

      ds = model.user_visible(SecurityContext.current_user, SecurityContext.admin?)
      ds = ds.filter(timestamp: start_time..end_time)

      collection_renderer.render_json(self.class, ds, self.class.path, @opts, {})
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    deprecated_endpoint '/v2/billing_events'

    private

    def start_time
      @start_time ||= parse_date_param('start_date')
    end

    def end_time
      @end_time ||= parse_date_param('end_date')
    end

    def parse_date_param(param)
      str = @params[param]
      Time.parse(str).utc if str
    rescue
      raise Errors::ApiError.new_from_details('BillingEventQueryInvalid')
    end

    def inject_dependencies(dependencies)
      super
      @collection_renderer = dependencies[:entity_only_paginated_collection_renderer]
      @object_renderer = nil
    end

    define_messages
    define_routes
  end
end
