class MaxDiskQuotaPolicy
  ERROR_MSG = 'too much disk requested (requested %<desired>s MB - must be less than %<max>s MB)'.freeze

  def initialize(app, max_mb)
    @app = app
    @errors = app.errors
    @max_mb = max_mb
  end

  def validate
    return unless @app.disk_quota
    if @app.disk_quota > @max_mb
      @errors.add(:disk_quota, sprintf(ERROR_MSG, desired: @app.disk_quota, max: @max_mb))
    end
  end
end
