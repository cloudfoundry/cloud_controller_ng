require 'active_model'

module VCAP::CloudController::Validators
  class MaintenanceInfoValidator < ActiveModel::Validator
    def validate(record)
      unless record.maintenance_info_message.valid?
        record.maintenance_info_message.errors.full_messages.each do |message|
          record.errors.add(:maintenance_info, message: message)
        end
      end
    end
  end
end
