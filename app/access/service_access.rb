module VCAP::CloudController::Models
  class ServiceAccess < BaseAccess
    def read?(service)
      super || logged_in?
    end
  end
end