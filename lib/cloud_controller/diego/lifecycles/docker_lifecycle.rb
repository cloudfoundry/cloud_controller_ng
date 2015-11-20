module VCAP::CloudController
  class DockerLifecycle
    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
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
  end
end
