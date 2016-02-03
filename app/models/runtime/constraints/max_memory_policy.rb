require 'cloud_controller/app_services/app_memory_calculator'

class BaseMaxMemoryPolicy
  def initialize(resource, policy_target, error_name)
    @resource = resource
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless policy_target
    return unless additional_checks

    unless policy_target.has_remaining_memory(requested_memory)
      resource.errors.add(field, error_name)
    end
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
    resource.scaling_operation?
  end

  def requested_memory
    calculator = VCAP::CloudController::AppMemoryCalculator.new(resource)
    calculator.additional_memory_requested
  end
end

class TaskMaxMemoryPolicy < BaseMaxMemoryPolicy
  private

  def field
    :memory_in_mb
  end
end
