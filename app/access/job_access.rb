module VCAP::CloudController
  class JobAccess < BaseAccess
    def read?(_)
      logged_in?
    end
  end
end
