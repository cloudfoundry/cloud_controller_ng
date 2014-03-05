module VCAP::CloudController
  class AppAccess < BaseAccess
    def create?(app)
      return super if super
      return false if app.in_suspended_org?
      app.space.developers.include?(context.user)
    end

    def update?(app)
      create?(app)
    end

    def delete?(app)
      create?(app)
    end
  end
end
