module VCAP::CloudController::Models
  class EventAccess < BaseAccess
    def read?(event)
      super ||
        [:developers, :auditors].any? do |type|
          event.space.send(type).include?(context.user)
        end
    end
  end
end