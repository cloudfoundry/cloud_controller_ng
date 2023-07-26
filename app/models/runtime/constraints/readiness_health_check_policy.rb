class ReadinessHealthCheckPolicy < HealthCheckPolicy
  def initialize(process, health_check_invocation_timeout, health_check_type, health_check_http_endpoint)
    super(process, nil, health_check_invocation_timeout, health_check_type, health_check_http_endpoint)
    @valid_health_check_types = VCAP::CloudController::HealthCheckTypes.constants_to_array - [VCAP::CloudController::HealthCheckTypes::NONE]
    @var_to_symbol = {
      'type' => :readiness_health_check_type,
      'invocation_timeout' => :readiness_health_check_invocation_timeout,
      'endpoint' => :readiness_health_check_http_endpoint
    }
  end

  def validate
    validate_type
    validate_invocation_timeout
    validate_health_check_type_and_port_presence_are_in_agreement
    validate_health_check_http_endpoint
  end

  private

  def http_endpoint_invalid_message
    "HTTP readiness health check endpoint is not a valid URI path: #{@health_check_http_endpoint}"
  end

  def port_presence_invalid_message
    'array cannot be empty when readiness health check type is "port"'
  end

  def is_health_check_type_port
    return true if @health_check_type == VCAP::CloudController::HealthCheckTypes::PORT

    return false
  end
end
