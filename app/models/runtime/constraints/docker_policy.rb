class DockerPolicy
  BUILDPACK_DETECTED_ERROR_MSG = 'incompatible with buildpack'.freeze
  DOCKER_CREDENTIALS_ERROR_MSG = 'user, password and email required'.freeze

  def initialize(app)
    @errors = app.errors
    @app = app
  end

  def validate
    if @app.docker_image.present? && @app.buildpack_specified?
      @errors.add(:docker_image, BUILDPACK_DETECTED_ERROR_MSG)
    end

    if @app.docker_image.present? && VCAP::CloudController::FeatureFlag.disabled?('diego_docker')
      @errors.add(:docker, :docker_disabled) if @app.being_started?
    end

    docker_credentials = @app.docker_credentials_json
    if docker_credentials.present?
      unless docker_credentials['docker_user'].present? && docker_credentials['docker_password'].present? && docker_credentials['docker_email'].present?
        @errors.add(:docker_credentials, DOCKER_CREDENTIALS_ERROR_MSG)
      end
    end
  end
end
