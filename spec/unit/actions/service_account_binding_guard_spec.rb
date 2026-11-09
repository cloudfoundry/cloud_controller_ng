require 'spec_helper'
require 'actions/app_assign_service_account'

module VCAP::CloudController
  RSpec.describe 'Service account identity binding guard' do
    it 'counts identity-bearing bindings as account lifecycle references' do
      space = create(:space)
      account = ServiceAccountModel.create(name: 'binding-worker', space: space, status: 'ready')
      app = create(:app_model, space: space, service_account: account)
      create(:service_binding, app: app, service_instance: create(:managed_service_instance, space: space))
      app.update(service_account: nil)
      expect(account.in_use?).to be(true)
      expect(account.in_use_in_space?(space)).to be(true)
    end

    it 'allows removing an assignment when the binding predates account assignment' do
      space = create(:space, organization: create(:organization, service_account_prefix: 'binding-team'))
      app = create(:app_model, space: space)
      create(:service_binding, app: app, service_instance: create(:managed_service_instance, space: space))
      account = ServiceAccountModel.create(name: 'binding-worker', space: space, status: 'ready')
      permissions = double(can_write_to_active_space?: true)
      action = AppAssignServiceAccount.new(permissions)
      action.assign(app, account)
      expect { action.assign(app, nil) }.not_to raise_error
    end

    it 'refuses to unassign an account while a broker binding depends on the identity' do
      space = create(:space)
      account = ServiceAccountModel.create(name: 'binding-worker', space: space, status: 'ready')
      app = create(:app_model, space: space, service_account: account)
      create(:service_binding, app: app, service_instance: create(:managed_service_instance, space: space))
      permissions = double(can_write_to_active_space?: true)

      expect { AppAssignServiceAccount.new(permissions).assign(app, nil) }.to raise_error(AppAssignServiceAccount::Conflict, /bindings/)
      expect(app.reload.service_account_guid).to eq(account.guid)
    end
  end
end
