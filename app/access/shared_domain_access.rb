module VCAP::CloudController
  class SharedDomainAccess < BaseAccess
    def read?(*_)
      true
    end
  end
end
