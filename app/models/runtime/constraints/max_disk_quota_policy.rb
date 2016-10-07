class MaxDiskQuotaPolicy
  ERROR_MSG = 'too much disk requested (requested %s MB - must be less than %s MB)'.freeze

  def initialize(app, max_mb)
    @app = app
    @errors = app.errors
    @max_mb = max_mb
  end

  def validate
    return unless @app.disk_quota
    if @app.disk_quota > @max_mb
      @errors.add(:disk_quota, sprintf(ERROR_MSG, @app.disk_quota, @max_mb))
    end
  end
end
