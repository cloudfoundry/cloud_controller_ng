module VCAP::CloudController::Models
  class BuildpackAccess < BaseAccess
    def read_bits?(object)
      context.roles.admin?
    end
  end
end
