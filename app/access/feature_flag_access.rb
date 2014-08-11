module VCAP::CloudController
  class FeatureFlagAccess < BaseAccess
    def index?(_)
      admin_user? || has_read_scope?
    end

    def read?(_)
      admin_user? || has_read_scope?
    end
  end
end
