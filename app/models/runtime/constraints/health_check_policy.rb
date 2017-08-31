class HealthCheckPolicy
  def initialize(app, health_check_timeout)
    @app = app
    @errors = app.errors
    @health_check_timeout = health_check_timeout
  end

  def validate
    return unless @health_check_timeout
    @errors.add(:health_check_timeout, :less_than_zero) unless @health_check_timeout >= 0
    max_timeout = VCAP::CloudController::Config.config.get(:maximum_health_check_timeout)
    if @health_check_timeout > max_timeout
      @errors.add(:health_check_timeout, "Maximum exceeded: max #{max_timeout}s")
    end
  end
end
