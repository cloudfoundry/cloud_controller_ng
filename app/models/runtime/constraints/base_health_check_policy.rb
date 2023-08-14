require 'models/helpers/health_check_types'
require 'utils/uri_utils'

# NOTE: nothing uses just the BaseHealthCheckPolicy. It is only used for
# inheritance.
class BaseHealthCheckPolicy
  def initialize(process, health_check_timeout, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval)
    @process = process
    @errors = process.errors
    @health_check_timeout = health_check_timeout
    @health_check_invocation_timeout = health_check_invocation_timeout
    @health_check_interval = health_check_interval
    @health_check_type = health_check_type
    @health_check_http_endpoint = health_check_http_endpoint
    @valid_health_check_types = VCAP::CloudController::HealthCheckTypes.all_types
    @var_presenter = {
      'timeout' => { sym: :health_check_timeout, str: 'health check timeout' },
      'type' => { sym: :health_check_type, str: 'health check type' },
      'invocation_timeout' => { sym: :health_check_invocation_timeout, str: 'health check invocation timeout' },
      'interval' => { sym: :health_check_interval, str: 'health check interval' },
      'endpoint' => { sym: :health_check_http_endpoint, str: 'health check endpoint' },
    }
  end

  def validate
    validate_type
    validate_timeout
    validate_invocation_timeout
    validate_interval
    validate_health_check_type_and_port_presence_are_in_agreement
    validate_health_check_http_endpoint
  end

  private

  def validate_timeout
    return unless @health_check_timeout

    @errors.add(:health_check_timeout, :less_than_one) if @health_check_timeout < 1
    max_timeout = VCAP::CloudController::Config.config.get(:maximum_health_check_timeout)
    if @health_check_timeout > max_timeout
      @errors.add(@var_presenter['timeout'][:sym], "Maximum exceeded: max #{max_timeout}s")
    end
  end

  def port_presence_invalid_message
    "array cannot be empty when #{@var_presenter['type'][:str]} is \"port\""
  end

  def http_endpoint_invalid_message
    "HTTP #{@var_presenter['endpoint'][:str]} is not a valid URI path: #{@health_check_http_endpoint}"
  end

  def validate_invocation_timeout
    return unless @health_check_invocation_timeout

    @errors.add(@var_presenter['invocation_timeout'][:sym], :less_than_one) if @health_check_invocation_timeout < 1
  end

  def validate_interval
    return unless @health_check_interval

    @errors.add(@var_presenter['interval'][:sym], :less_than_one) if @health_check_interval < 1
  end

  def validate_health_check_type_and_port_presence_are_in_agreement
    if is_health_check_type_port && @process.ports == []
      @errors.add(:ports, port_presence_invalid_message)
    end
  end

  def is_health_check_type_port
    @health_check_type == VCAP::CloudController::HealthCheckTypes::PORT
  end

  def validate_health_check_http_endpoint
    if @health_check_type == VCAP::CloudController::HealthCheckTypes::HTTP && \
        !UriUtils.is_uri_path?(@health_check_http_endpoint)
      @errors.add(@var_presenter['endpoint'][:sym], http_endpoint_invalid_message)
    end
  end

  def validate_type
    error_msg = 'must be one of ' + @valid_health_check_types.join(', ')

    unless @health_check_type.nil?
      unless @valid_health_check_types.include? @health_check_type
        @errors.add(@var_presenter['type'][:sym], error_msg)
      end
    end
  end
end
