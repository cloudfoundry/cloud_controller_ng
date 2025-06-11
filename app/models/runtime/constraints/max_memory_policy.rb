require 'cloud_controller/app_services/process_memory_calculator'

class BaseMaxMemoryPolicy
  def initialize(resource, policy_target, error_name)
    @resource = resource
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless policy_target
    return unless additional_checks

    return if policy_target.has_remaining_memory(requested_memory)

    resource.errors.add(field, "exceeded for space #{policy_target.name}. This space's quota may not be large enough to support rolling deployments or your configured max-in-flight")

  end

  private

  attr_reader :resource, :policy_target, :error_name

  def additional_checks
    true
  end

  def requested_memory
    resource.public_send field
  end

  def field
    :memory
  end
end

class AppMaxMemoryPolicy < BaseMaxMemoryPolicy
  private

  def additional_checks
    resource.started?
  end

  def requested_memory
    calculator = VCAP::CloudController::ProcessMemoryCalculator.new(resource)
    calculator.additional_memory_requested
  end
end

class TaskMaxMemoryPolicy < BaseMaxMemoryPolicy
  IGNORED_STATES = [
    VCAP::CloudController::TaskModel::CANCELING_STATE,
    VCAP::CloudController::TaskModel::SUCCEEDED_STATE,
    VCAP::CloudController::TaskModel::FAILED_STATE
  ].freeze

  private

  def additional_checks
    IGNORED_STATES.exclude?(resource.state)
  end

  def field
    :memory_in_mb
  end
end
