module VCAP::CloudController
  class BuildpackAccess < BaseAccess
    def read_bits?(_)
      context.roles.admin?
    end
  end
end
