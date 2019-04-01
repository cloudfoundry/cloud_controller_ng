class DockerPolicy
  BUILDPACK_DETECTED_ERROR_MSG = 'incompatible with buildpack'.freeze
  DOCKER_CREDENTIALS_ERROR_MSG = 'user, password and email required'.freeze

  def initialize(process)
    @errors = process.errors
    @process = process
  end

  def validate
    if @process.docker_image
      if @process.buildpack_specified?
        @errors.add(:docker_image, BUILDPACK_DETECTED_ERROR_MSG)
      end

      if VCAP::CloudController::FeatureFlag.disabled?(:diego_docker)
        @errors.add(:docker, :docker_disabled) if @process.being_started?
      end
    end
  end
end
