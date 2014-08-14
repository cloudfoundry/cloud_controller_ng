module VCAP::CloudController
  class QuotaDefinitionAccess < BaseAccess
    def read?(_)
      admin_user?
    end
  end
end
