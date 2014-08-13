module VCAP::CloudController
  class AppAccess < BaseAccess
    def create?(app, params=nil)
      return true if admin_user?
      return false if app.in_suspended_org?
      app.space.developers.include?(context.user)
    end

    def read_for_update?(app, params=nil)
      create?(app, params)
    end

    def update?(app, params=nil)
      create?(app, params)
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
