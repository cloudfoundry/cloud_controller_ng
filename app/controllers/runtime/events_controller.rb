require 'vcap/rest_api/event_query'

module VCAP::CloudController
  class EventsController < RestController::ModelController
    query_parameters :timestamp, :type, :actee, :space_guid, :organization_guid
    sortable_parameters :timestamp, :id

    def initialize(*args)
      super
      @opts.merge!(order_by: [:timestamp, :id])
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      EventQuery.filtered_dataset_from_query_params(model, ds, qp, opts)
    end

    define_messages
    define_routes
  end
end
