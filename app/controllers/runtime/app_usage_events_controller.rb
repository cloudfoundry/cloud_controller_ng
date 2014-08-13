require "repositories/runtime/app_usage_event_repository"

module VCAP::CloudController
  class AppUsageEventsController < RestController::ModelController
    preserve_query_parameters :after_guid

    get "/v2/app_usage_events", :enumerate

    get "#{path_guid}", :read

    post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", :reset

    def reset
      validate_access(:reset, model)

      repository = Repositories::Runtime::AppUsageEventRepository.new
      repository.purge_and_reseed_started_apps!

      [HTTP::NO_CONTENT, nil]
    end

    def self.not_found_exception_name
      "EventNotFound"
    end

    private

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      after_guid = params["after_guid"]
      if after_guid
        repository = Repositories::Runtime::AppUsageEventRepository.new
        previous_event = repository.find(after_guid)
        raise Errors::ApiError.new_from_details("BadQueryParameter", after_guid) unless previous_event
        ds = ds.filter{ id > previous_event.id }
      end
      super(model, ds, qp, opts)
    end
  end
end
