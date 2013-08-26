module VCAP::CloudController::Models
  class BaseAccess
    include Allowy::AccessControl

    def create?(object)
      context.roles.admin?
    end

    def read?(object)
      context.roles.admin? || !object.class.user_visible(context.user).where(:guid => object.guid).empty?
    end

    def update?(object)
      context.roles.admin?
    end

    def delete?(object)
      context.roles.admin?
    end

    def logged_in?
      !context.user.nil? || context.roles.present?
    end
  end
end
