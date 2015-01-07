module VCAP::CloudController
  class AppEventsController < RestController::ModelController
    define_attributes do
      to_one :app
      attribute :instance_guid, String
      attribute :instance_index, Integer
      attribute :exit_status, Integer
      attribute :timestamp, String
    end

    deprecated_endpoint '/v2/app_events'

    query_parameters :timestamp, :app_guid

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes
  end
end
