module VCAP::CloudController
  class JobAccess < BaseAccess
    def read?(object)
      logged_in?
    end
  end
end
