module VCAP::CloudController
  class AppAssignServiceAccount
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Conflict < Error; end

    def initialize(permissions)
      @permissions = permissions
    end

    def assign(app, account)
      app.db.transaction do
        app.lock!
        raise Unauthorized.new('not authorized to update the app') unless @permissions.can_write_to_active_space?(app.space.id)

        if account
          account.lock!
          raise Conflict.new('account must belong to the app owning space') unless account.space_guid == app.space_guid
          raise Conflict.new('service account is not ready or enabled') unless account.enabled && account.status == 'ready'
          raise Conflict.new('another service account is already assigned; unbind first') if app.service_account_guid && app.service_account_guid != account.guid
        end

        app.update(service_account: account) unless app.service_account_guid == account&.guid
      end
      app
    end
  end
end
