class DockerPolicy
  BUILDPACK_DETECTED_ERROR_MSG = "incompatible with buildpack"
  DOCKER_DISABLED_ERROR_MSG = "not supported with diego or docker disabled"

  def initialize(app, diego_enabled, docker_enabled)
    @diego_enabled = diego_enabled
    @docker_enabled = docker_enabled
    @errors = app.errors
    @app = app
  end

  def validate
    return unless @app.docker_image.present?

    if @app.buildpack_specified?
      @errors.add(:docker_image, BUILDPACK_DETECTED_ERROR_MSG)
    end

    if !@diego_enabled || !@docker_enabled
      @errors.add(:docker_image, DOCKER_DISABLED_ERROR_MSG)
    end
  end
end
