module VCAP::CloudController::Models
  class StackAccess < BaseAccess
    def read?(stack)
      super || !context.user.nil? || context.roles.present?
    end
  end
end