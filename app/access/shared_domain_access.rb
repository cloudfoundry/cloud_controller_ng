module VCAP::CloudController
  class SharedDomainAccess < BaseAccess
    def read?(_)
      admin_user? || logged_in?
    end
  end
end
