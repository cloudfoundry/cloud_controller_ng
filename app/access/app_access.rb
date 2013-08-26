module VCAP::CloudController::Models
  class AppAccess < BaseAccess
    def create?(app)
      super || app.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?
  end
end
