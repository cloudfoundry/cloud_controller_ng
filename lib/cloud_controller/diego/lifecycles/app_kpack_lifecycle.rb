module VCAP::CloudController
  class AppKpackLifecycle
    def initialize(*_message); end

    def create_lifecycle_data_model(app)
      KpackLifecycleDataModel.create(app: app)
    end

    def update_lifecycle_data_model(_); end

    def valid?
      true
    end

    def errors
      []
    end

    def type
      Lifecycles::KPACK
    end
  end
end
