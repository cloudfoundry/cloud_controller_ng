module VCAP::CloudController
  class AppAccess < BaseAccess
    def create?(app)
      super || app.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
