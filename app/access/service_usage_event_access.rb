module VCAP::CloudController
  class ServiceUsageEventAccess < BaseAccess
    def index?(*_)
      admin_user?
    end

    def reset?(*_)
      admin_user?
    end

    def reset_with_token?(_)
      admin_user?
    end
  end
end
