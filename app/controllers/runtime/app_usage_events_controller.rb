module VCAP::CloudController
  class AppUsageEventsController < RestController::ModelController
    preserve_query_parameters :after_guid

    get "/v2/app_usage_events", :enumerate

    private
    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      if after_guid = params["after_guid"]
        previous_event = AppUsageEvent.find(guid: after_guid)
        raise Errors::BadQueryParameter, after_guid unless previous_event
        ds = ds.filter{ id > previous_event.id }
      end
      super(model, ds, qp, opts)
    end
  end
end
