module VCAP::CloudController
  class EventsController < RestController::ModelController
    define_attributes do
      to_one :space
    end

    query_parameters :timestamp, :type, :actee

    def initialize(*args)
      super
      @opts.merge!(order_by: :timestamp)
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes
  end
end
