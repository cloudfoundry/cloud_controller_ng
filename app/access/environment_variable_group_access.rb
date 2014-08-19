module VCAP::CloudController
  class EnvironmentVariableGroupAccess < BaseAccess
    def read?(_)
      admin_user? || has_read_scope?
    end
  end
end
