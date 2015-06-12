class MaxDiskQuotaPolicy
  ERROR_MSG = 'too much disk requested (must be less than %s)'

  def initialize(app, max_mb)
    @app = app
    @errors = app.errors
    @max_mb = max_mb
  end

  def validate
    return unless @app.disk_quota
    if @app.disk_quota > @max_mb
      @errors.add(:disk_quota, ERROR_MSG % @max_mb)
    end
  end
end
