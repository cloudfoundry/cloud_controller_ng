require 'services/api'

module VCAP::CloudController
  class ServiceUsageEventsController < RestController::ModelController
    query_parameters :service_instance_type, :service_guid

    preserve_query_parameters :after_guid

    get '/v2/service_usage_events', :enumerate

    get "#{path_guid}", :read

    post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances', :reset
    def reset
      validate_access(:reset, model)

      repository = Repositories::Services::ServiceUsageEventRepository.new
      repository.purge_and_reseed_service_instances!

      [HTTP::NO_CONTENT, nil]
    end

    def self.not_found_exception_name
      'EventNotFound'
    end

    private

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      after_guid = params['after_guid']
      if after_guid
        repository = Repositories::Services::ServiceUsageEventRepository.new
        previous_event = repository.find(after_guid)
        raise Errors::ApiError.new_from_details('BadQueryParameter', after_guid) unless previous_event
        ds = ds.filter { id > previous_event.id }
      end
      super(model, ds, qp, opts)
    end
  end
end
