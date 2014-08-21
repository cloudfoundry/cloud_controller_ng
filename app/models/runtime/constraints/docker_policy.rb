class DockerPolicy
  INVALID_ERROR_MSG = "incompatible with buildpack"

  def initialize(app)
    @errors = app.errors
    @app = app
  end

  def validate
    return unless @app.docker_image.present?
    if !@app.auto_buildpack?
      @errors.add(:docker_image, INVALID_ERROR_MSG)
    end
  end
end
