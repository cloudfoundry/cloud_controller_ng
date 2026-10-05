module VCAP::CloudController
  class AppAssignServiceAccount
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Conflict < Error; end

    def initialize(permissions)
      @permissions = permissions
    end

    def assign(app, account, provision: false)
      job = nil
      app.db.transaction do
        app.lock!
        raise Unauthorized.new('not authorized to update the app') unless @permissions.can_write_to_active_space?(app.space.id)

        if account
          account.lock!
          raise Conflict.new('account must belong to the app owning space') unless account.space_guid == app.space_guid

          validate_ready!(account, provision)
          raise Conflict.new('another service account is already assigned; unbind first') if app.service_account_guid && app.service_account_guid != account.guid

          job = provision_account(account) unless account.status == 'ready'
        end

        app.update(service_account: account) unless app.service_account_guid == account&.guid
      end
      provision ? job : app
    end

    private

    def validate_ready!(account, provision)
      raise Conflict.new('service account is not ready or enabled') unless account.enabled && (account.status == 'ready' || provision)
    end

    def provision_account(account)
      job = PollableJobModel.first(resource_guid: account.guid, operation: 'service_account.provision', state: %w[PROCESSING POLLING])
      return job if job

      account.update(status: 'reconciling')
      Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(Jobs::V3::ServiceAccountProvision.new(account.guid))
    end
  end
end
