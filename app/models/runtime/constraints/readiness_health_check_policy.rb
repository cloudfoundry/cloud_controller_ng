class ReadinessHealthCheckPolicy < BaseHealthCheckPolicy
  def initialize(process, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval)
    super(process, nil, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval)
    @valid_health_check_types = VCAP::CloudController::HealthCheckTypes.readiness_types
    @var_presenter = {
      'type' => { sym: :readiness_health_check_type, str: 'readiness health check type' },
      'invocation_timeout' => { sym: :readiness_health_check_invocation_timeout, str: 'readiness health check invocation timeout' },
      'interval' => { sym: :readiness_health_check_interval, str: 'readiness health check interval' },
      'endpoint' => { sym: :readiness_health_check_http_endpoint, str: 'readiness health check endpoint' }
    }
  end

  private

  def validate_timeout
    # No timeout for readiness health checks.
    # This timeout is different than the invocation timeout.
  end
end
