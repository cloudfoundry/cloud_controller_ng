module VCAP::CloudController
  rest_controller :Tasks do
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
      super
    end
  end
end
