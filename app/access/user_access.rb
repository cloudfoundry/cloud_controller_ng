module VCAP::CloudController::Models
  class UserAccess
    include Allowy::AccessControl

    def create?(user)
      context.roles.admin?
    end

    alias :read? :create?
    alias :update? :create?
    alias :delete? :create?
  end
end