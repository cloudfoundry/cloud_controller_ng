class HealthCheckPolicy
  def initialize(process, health_check_timeout, health_check_invocation_timeout)
    @process = process
    @errors = process.errors
    @health_check_timeout = health_check_timeout
    @health_check_invocation_timeout = health_check_invocation_timeout
  end

  def validate
    validate_timeout
    validate_invocation_timeout
  end

  private

  def validate_timeout
    return unless @health_check_timeout

    @errors.add(:health_check_timeout, :less_than_one) if @health_check_timeout < 1
    max_timeout = VCAP::CloudController::Config.config.get(:maximum_health_check_timeout)
    if @health_check_timeout > max_timeout
      @errors.add(:health_check_timeout, "Maximum exceeded: max #{max_timeout}s")
    end
  end

  def validate_invocation_timeout
    return unless @health_check_invocation_timeout

    @errors.add(:health_check_invocation_timeout, :less_than_one) if @health_check_invocation_timeout < 1
  end
end
