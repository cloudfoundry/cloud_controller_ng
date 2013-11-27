module VCAP::CloudController
  class TasksController < RestController::ModelController
    define_attributes do
      to_one :app
    end

    def create
      return [HTTP::NOT_FOUND, nil] if config[:tasks_disabled]
      super
    end

    def read(guid)
      return [HTTP::NOT_FOUND, nil] if config[:tasks_disabled]
      super
    end

    def update(guid)
      return [HTTP::NOT_FOUND, nil] if config[:tasks_disabled]
      super
    end

    def delete(guid)
      return [HTTP::NOT_FOUND, nil] if config[:tasks_disabled]
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes
  end
end
