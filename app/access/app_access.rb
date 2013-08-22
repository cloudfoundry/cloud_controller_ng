module VCAP::CloudController::Models
  class AppAccess < BaseAccess
    def create?(app)
      super || app.space.developers.include?(context.user)
    end

    alias :update? :create?
    alias :delete? :create?

    def read?(app)
      super || app.space.organization.managers.include?(context.user) || [:developers, :managers, :auditors].any? do |type|
        app.space.send(type).include?(context.user)
      end
    end
  end
end