module VCAP::CloudController::Models
  class JobAccess < BaseAccess
    def read?(object)
      logged_in?
    end
  end
end
