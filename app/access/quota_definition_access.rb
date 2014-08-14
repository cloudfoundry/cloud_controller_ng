module VCAP::CloudController
  class QuotaDefinitionAccess < BaseAccess
    def index?(_)
      admin_user?
    end
  end
end
