module VCAP::CloudController
  class AppDockerLifecycle
    def create_lifecycle_data_model(_)
    end

    def update_lifecycle_data_model(_)
    end

    def valid?
      true
    end

    def errors
      []
    end

    def type
      Lifecycles::DOCKER
    end
  end
end
