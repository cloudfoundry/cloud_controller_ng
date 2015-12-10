module VCAP::CloudController
  class DockerLifecycle
    attr_reader :staging_message

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
    end

    def type
      Lifecycles::DOCKER
    end

    def create_lifecycle_data_model(_)
    end

    def staging_environment_variables
      {}
    end

    def pre_known_receipt_information
      {
        docker_receipt_image: @package.docker_data.image
      }
    end

    def valid?
      true
    end

    def errors
      []
    end
  end
end
