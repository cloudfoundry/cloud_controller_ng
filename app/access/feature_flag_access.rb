module VCAP::CloudController
  class FeatureFlagAccess < BaseAccess
    def index?(_)
      admin_user?
    end

    def read?(_)
      admin_user?
    end
  end
end
