require 'active_model'

module VCAP::CloudController::Validators
  class MaintenanceInfoValidator < ActiveModel::Validator
    def validate(record)
      unless record.maintenance_info_message.valid?
        record.errors[:maintenance_info].concat(record.maintenance_info_message.errors.full_messages)
      end
    end
  end
end
