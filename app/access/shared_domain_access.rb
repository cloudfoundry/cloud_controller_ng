module VCAP::CloudController
  class SharedDomainAccess < BaseAccess
    def read?(_)
      logged_in?
    end
  end
end
