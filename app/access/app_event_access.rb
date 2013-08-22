module VCAP::CloudController::Models
  class AppEventAccess < BaseAccess
    def read?(app_event)
      super || [:users, :managers].any? do |type|
        app_event.app.space.organization.send(type).include?(context.user)
      end
    end
  end
end