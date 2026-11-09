require 'repositories/service_account_event_repository'

module VCAP::CloudController
  class AppAssignServiceAccount
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Conflict < Error; end

    def initialize(permissions, actor: nil)
      @permissions = permissions
      @actor = actor
    end

    def assign(app, account, provision: false)
      job = nil
      app.db.transaction do
        app.lock!
        raise Unauthorized.new('not authorized to update the app') unless @permissions.can_write_to_active_space?(app.space.id)

        validate_binding_change!(app, account)

        if account
          account.lock!
          raise Conflict.new('organization service account prefix is unset') unless account.organization.service_account_prefix
          raise Conflict.new('account must be entitled to the app space in the same organization') unless account.entitled_to?(app.space)

          validate_ready!(account, provision)
          raise Conflict.new('another service account is already assigned; unbind first') if app.service_account_guid && app.service_account_guid != account.guid

          job = provision_account(account) unless account.status == 'ready'
        end

        unless app.service_account_guid == account&.guid
          previous_guid = app.service_account_guid
          app.update(service_account: account)
          record_assignment(app, account, previous_guid) if @actor
        end
      end
      provision ? job : app
    end

    private

    def validate_binding_change!(app, account)
      return unless app.service_account_guid && app.service_account_guid != account&.guid && app.service_bindings_dataset.any?

      raise Conflict.new('remove service bindings before changing the service account')
    end

    def record_assignment(app, account, previous_guid)
      Repositories::ServiceAccountEventRepository.record(
        app, account ? 'assign' : 'unassign', @actor,
        service_account_guid: account&.guid || previous_guid
      )
    end

    def validate_ready!(account, provision)
      raise Conflict.new('service account is not ready or enabled') unless account.enabled && (account.status == 'ready' || provision)

      if PollableJobModel.where(resource_guid: account.guid, resource_type: 'service_account', state: %w[PROCESSING POLLING]).exclude(operation: 'service_account.provision').any?
        raise Conflict.new('service account lifecycle operation is in progress')
      end
    end

    def provision_account(account)
      job = PollableJobModel.first(resource_guid: account.guid, operation: 'service_account.provision', state: %w[PROCESSING POLLING])
      return job if job

      account.update(status: 'reconciling')
      Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(Jobs::V3::ServiceAccountProvision.new(account.guid))
    end
  end
end
