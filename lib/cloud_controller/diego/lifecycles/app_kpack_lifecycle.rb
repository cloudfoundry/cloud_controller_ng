module VCAP::CloudController
  class AppKpackLifecycle
    def initialize(*_message); end

    def create_lifecycle_data_model(app)
      app.kpack_lifecycle_data = KpackLifecycleDataModel.create(app: app)
    end

    # oh noes
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
