class DockerPolicy
  BUILDPACK_DETECTED_ERROR_MSG = 'incompatible with buildpack'.freeze
  DOCKER_CREDENTIALS_ERROR_MSG = 'user, password and email required'.freeze

  def initialize(app)
    @errors = app.errors
    @app    = app
  end

  def validate
    if @app.docker_image
      if @app.buildpack_specified?
        @errors.add(:docker_image, BUILDPACK_DETECTED_ERROR_MSG)
      end

      if VCAP::CloudController::FeatureFlag.disabled?(:diego_docker)
        @errors.add(:docker, :docker_disabled) if @app.being_started?
      end
    end
  end
end
