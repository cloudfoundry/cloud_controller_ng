module VCAP::CloudController
  class BaseAccess
    include Allowy::AccessControl

    def create?(object)
      admin_user?
    end

    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)
      @ok_read = (admin_user? || object.class.user_visible(context.user, context.roles.admin?).where(:guid => object.guid).count > 0)
    end

    def update?(object)
      admin_user?
    end

    def delete?(object)
      admin_user?
    end

    def index?(object_class)
      true
    end

    def logged_in?
      !context.user.nil? || context.roles.present?
    end

    private

    def admin_user?
      return @admin_user if instance_variable_defined?(:@admin_user)
      @admin_user = context.roles.admin?
    end
  end
end
