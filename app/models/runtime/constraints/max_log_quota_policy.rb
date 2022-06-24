require 'cloud_controller/app_services/process_log_quota_calculator'

class BaseMaxLogQuotaPolicy
  def initialize(resource, policy_target, error_name)
    @resource = resource
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless policy_target
    return unless additional_checks

    if resource.log_quota == VCAP::CloudController::QuotaDefinition::UNLIMITED &&
       policy_target.log_limit != VCAP::CloudController::QuotaDefinition::UNLIMITED

       resource.errors.add(field, :app_requires_log_quota_to_be_specified)
    end

    unless policy_target.has_remaining_log_quota(requested_log_quota)
      resource.errors.add(field, error_name)
    end
  end

  private

  attr_reader :resource, :policy_target, :error_name

  def additional_checks
    true
  end

  def requested_log_quota
    resource.public_send field
  end

  def field
    :log_quota
  end
end

class AppMaxLogQuotaPolicy < BaseMaxLogQuotaPolicy
  private

  def additional_checks
    resource.scaling_operation?
  end

  def requested_log_quota
    calculator = VCAP::CloudController::ProcessLogQuotaCalculator.new(resource)
    calculator.additional_log_quota_requested
  end
end

class TaskMaxLogQuotaPolicy < BaseMaxLogQuotaPolicy
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
    :log_quota
  end
end
