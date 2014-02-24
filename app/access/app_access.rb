module VCAP::CloudController
  class AppAccess < BaseAccess
    def create?(app)
      super || app.space.developers.include?(context.user)
    end

    alias_method :update?, :create?
    alias_method :delete?, :create?
  end
end
