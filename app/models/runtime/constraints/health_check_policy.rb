require 'models/helpers/health_check_types'
require 'utils/uri_utils'

class HealthCheckPolicy
  def initialize(process, health_check_timeout, health_check_invocation_timeout, health_check_type, health_check_http_endpoint)
    @process = process
    @errors = process.errors
    @health_check_timeout = health_check_timeout
    @health_check_invocation_timeout = health_check_invocation_timeout
    @health_check_type = health_check_type
    @health_check_http_endpoint = health_check_http_endpoint
    @valid_health_check_types = VCAP::CloudController::HealthCheckTypes.constants_to_array
    @var_to_symbol = {
      'timeout' => :health_check_timeout,
      'type' => :health_check_type,
      'invocation_timeout' => :health_check_invocation_timeout,
      'endpoint' => :health_check_http_endpoint
    }
  end

  def validate
    validate_type
    validate_timeout
    validate_invocation_timeout
    validate_health_check_type_and_port_presence_are_in_agreement
    validate_health_check_http_endpoint
  end

  private

  def validate_timeout
    return unless @health_check_timeout

    @errors.add(:health_check_timeout, :less_than_one) if @health_check_timeout < 1
    max_timeout = VCAP::CloudController::Config.config.get(:maximum_health_check_timeout)
    if @health_check_timeout > max_timeout
      @errors.add(@var_to_symbol['timeout'], "Maximum exceeded: max #{max_timeout}s")
    end
  end

  def validate_invocation_timeout
    return unless @health_check_invocation_timeout

    @errors.add(@var_to_symbol['invocation_timeout'], :less_than_one) if @health_check_invocation_timeout < 1
  end

  def port_presence_invalid_message
    'array cannot be empty when health check type is "port"'
  end

  def validate_health_check_type_and_port_presence_are_in_agreement
    if is_health_check_type_port && @process.ports == []
      @errors.add(:ports, port_presence_invalid_message)
    end
  end

  def is_health_check_type_port
    return true if @health_check_type == VCAP::CloudController::HealthCheckTypes::PORT
    # health checks default to type port, this results in the health check type
    # being stored as nil in the db
    return true if @health_check_type.nil?

    return false
  end

  def validate_health_check_http_endpoint
    if @health_check_type == VCAP::CloudController::HealthCheckTypes::HTTP && \
        !UriUtils.is_uri_path?(@health_check_http_endpoint)
      @errors.add(@var_to_symbol['endpoint'], http_endpoint_invalid_message)
    end
  end

  def http_endpoint_invalid_message
    "HTTP health check endpoint is not a valid URI path: #{@health_check_http_endpoint}"
  end

  def validate_type
    error_msg = 'must be one of ' + @valid_health_check_types.join(', ')

    unless @health_check_type.nil? # The original validation allowed for missing health_check_types
      unless @valid_health_check_types.include? @health_check_type
        @errors.add(@var_to_symbol['type'], error_msg)
      end
    end
  end
end
