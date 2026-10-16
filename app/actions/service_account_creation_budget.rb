module VCAP::CloudController
  class ServiceAccountCreationBudget
    WINDOW = 7.days

    def self.consume(principal, exempt:)
      return yield if exempt

      # Lock the authenticated principal, not a space: requests on different API
      # instances and in different spaces must share one atomic budget.
      principal.lock!
      now = Time.now.utc
      creations = ServiceAccountModel.db[:service_account_creations]
      limit = Config.config.get(:service_account_creation_limit) || -1
      used = creations.where(principal_guid: principal.guid).where { created_at > now - WINDOW }.count
      raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountCreationLimitExceeded') if limit.between?(0, used)

      result = yield
      # Independent of accounts, tombstones and audit-event retention. Failed
      # creations roll this back; successful deletions never refund the budget.
      creations.insert(principal_guid: principal.guid, created_at: now) # rubocop:disable Rails/SkipsModelValidations -- Transactional creation ledger, not an ActiveRecord model.
      creations.where(principal_guid: principal.guid).where { created_at <= now - WINDOW }.delete
      result
    end
  end
end
