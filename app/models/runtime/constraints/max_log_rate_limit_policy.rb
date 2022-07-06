require 'cloud_controller/app_services/process_log_rate_limit_calculator'

class BaseMaxLogRateLimitPolicy
  def initialize(resource, policy_target, error_name)
    @resource = resource
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless policy_target
    return unless additional_checks

    if requested_log_rate_limit == VCAP::CloudController::QuotaDefinition::UNLIMITED &&
      policy_target.log_rate_limit != VCAP::CloudController::QuotaDefinition::UNLIMITED

      policy_target_type = if policy_target.respond_to?(:organization_guid)
                             'space'
                           else
                             'organization'
                           end

      resource.errors.add(field, "cannot be unlimited in #{policy_target_type} '#{policy_target.name}'.")
    end

    unless policy_target.has_remaining_log_rate_limit(requested_log_rate_limit)
      resource.errors.add(field, error_name)
    end
  end

  private

  attr_reader :resource, :policy_target, :error_name

  def additional_checks
    true
  end

  def requested_log_rate_limit
    resource.public_send field
  end

  def field
    :log_rate_limit
  end
end

class AppMaxLogRateLimitPolicy < BaseMaxLogRateLimitPolicy
  private

  def additional_checks
    resource.started? &&
      (resource.column_changed?(:state) || resource.column_changed?(:instances))
  end

  def requested_log_rate_limit
    calculator = VCAP::CloudController::ProcessLogRateLimitCalculator.new(resource)
    calculator.additional_log_rate_limit_requested
  end
end

class TaskMaxLogRateLimitPolicy < BaseMaxLogRateLimitPolicy
  IGNORED_STATES = [
    VCAP::CloudController::TaskModel::CANCELING_STATE,
    VCAP::CloudController::TaskModel::SUCCEEDED_STATE,
    VCAP::CloudController::TaskModel::FAILED_STATE,
  ].freeze

  private

  def additional_checks
    IGNORED_STATES.exclude?(resource.state)
  end

  def field
    :log_rate_limit
  end
end
