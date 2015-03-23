class MinDiskQuotaPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    @errors.add(:disk_quota, :zero_or_less) unless @app.disk_quota > 0
  end
end
