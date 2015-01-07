class DockerPolicy
  BUILDPACK_DETECTED_ERROR_MSG = 'incompatible with buildpack'

  def initialize(app)
    @errors = app.errors
    @app = app
  end

  def validate
    if @app.docker_image.present? && @app.buildpack_specified?
      @errors.add(:docker_image, BUILDPACK_DETECTED_ERROR_MSG)
    end
  end
end
