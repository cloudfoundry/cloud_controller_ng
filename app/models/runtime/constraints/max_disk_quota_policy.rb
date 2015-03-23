require 'cloud_controller/app_services/app_disk_quota_calculator'

class MaxDiskQuotaPolicy
  attr_reader :policy_target

  def initialize(app, policy_target, error_name)
    @app = app
    @errors = app.errors
    @policy_target = policy_target
    @error_name = error_name
    @calculator = VCAP::CloudController::AppDiskQuotaCalculator.new(@app)
  end

  def validate
    return unless @policy_target
    return unless @app.scaling_operation?

    unless @policy_target.has_remaining_disk_space(@calculator.additional_disk_quota_requested)
      @errors.add(:disk_quota, @error_name)
    end
  end
end
