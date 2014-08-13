module VCAP::CloudController
  class BuildpackAccess < BaseAccess
    def upload?(*_)
      admin_user?
    end

    def upload_with_token?(_)
      admin_user?
    end
  end
end
