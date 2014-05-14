module VCAP::CloudController
  class AppAccess < BaseAccess
    def create?(app)
      return true if admin_user?
      return false if app.in_suspended_org?
      app.space.developers.include?(context.user)
    end

    def update?(app)
      create?(app)
    end

    def delete?(app)
      create?(app)
    end

    def read_env?(app)
     return true if admin_user?
     app.space.developers.include?(context.user)
    end

    def read_env_with_token?(app)
      read_with_token?(app)
    end
  end
end
