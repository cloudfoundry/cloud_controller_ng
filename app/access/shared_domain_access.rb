module VCAP::CloudController
  class SharedDomainAccess < BaseAccess
    def read?(_)
      admin_user? || (has_read_scope? && logged_in?)
    end
  end
end
