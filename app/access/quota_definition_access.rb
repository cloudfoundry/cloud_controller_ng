module VCAP::CloudController::Models
  class QuotaDefinitionAccess < BaseAccess
    def read?(quota_definition)
      super || !context.user.nil? || context.roles.present?
    end
  end
end