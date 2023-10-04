class HealthCheckPolicy < BaseHealthCheckPolicy
  private

  def is_health_check_type_port
    return true if @health_check_type == VCAP::CloudController::HealthCheckTypes::PORT
    # liveness and startup health checks default to type port, this results in the health check type
    # being stored as nil in the db
    return true if @health_check_type.nil?

    false
  end
end
