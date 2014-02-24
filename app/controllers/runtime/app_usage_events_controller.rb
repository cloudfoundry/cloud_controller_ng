module VCAP::CloudController
  class AppUsageEventsController < RestController::ModelController
    preserve_query_parameters :after_guid

    get "/v2/app_usage_events", :enumerate

    post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", :reset

    def reset
      validate_access(:reset, model, user, roles)

      AppUsageEvent.db[:app_usage_events].truncate
      usage_query = App.join(:spaces, id: :apps__space_id).
        join(:organizations, id: :spaces__organization_id).
        select(:apps__guid, :apps__guid, :apps__name, :apps__state, :apps__instances, :apps__memory, :spaces__guid, :spaces__name, :organizations__guid, Sequel.datetime_class.now).
        where(:apps__state => 'STARTED').
        order(:apps__id)
      AppUsageEvent.insert([:guid, :app_guid, :app_name, :state, :instance_count, :memory_in_mb_per_instance, :space_guid, :space_name, :org_guid, :created_at], usage_query)

      [HTTP::NO_CONTENT, nil]
    end

    private
    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      after_guid = params["after_guid"]
      if after_guid
        previous_event = AppUsageEvent.find(guid: after_guid)
        raise Errors::BadQueryParameter, after_guid unless previous_event
        ds = ds.filter{ id > previous_event.id }
      end
      super(model, ds, qp, opts)
    end
  end
end
