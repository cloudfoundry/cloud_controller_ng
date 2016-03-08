class MinDiskQuotaPolicy
  ERROR_MSG = 'too little disk requested (must be greater than zero)'.freeze

  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    return unless @app.disk_quota
    if @app.disk_quota < 1
      @errors.add(:disk_quota, ERROR_MSG)
    end
  end
end
