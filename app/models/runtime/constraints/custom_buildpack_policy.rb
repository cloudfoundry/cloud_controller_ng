class CustomBuildpackPolicy
  ERROR_MSG = 'custom buildpacks are disabled'

  def initialize(app, custom_buildpacks_enabled)
    @custom_buildpacks_enabled = custom_buildpacks_enabled
    @errors = app.errors
    @app = app
  end

  def validate
    return unless @app.buildpack_changed?
    return if @custom_buildpacks_enabled
    if @app.buildpack.custom?
      @errors.add(:buildpack, ERROR_MSG)
    end
  end
end
