require 'spec_helper'
require 'actions/app_assign_service_account' if File.exist?('app/actions/app_assign_service_account.rb')

module VCAP::CloudController
  RSpec.describe 'Same-space service account assignment' do
    let(:space) { create(:space, organization: create(:organization, service_account_prefix: 'assignment-team')) }
    let(:app) { create(:app_model, space: space) }
    let(:account) { VCAP::CloudController.const_get(:ServiceAccountModel).create(name: 'payments-worker', space: space, status: 'ready') }
    let(:permissions) { instance_double(Permissions, can_write_to_active_space?: true) }
    let(:action) { VCAP::CloudController.const_get(:AppAssignServiceAccount).new(permissions) }

    it 'allows an app writer to use an account in the owning space without a use grant' do
      action.assign(app, account)
      expect(app.reload.service_account).to eq(account)
      expect(app.desired_state).to eq('STOPPED')
    end

    it 'denies callers without app-write permission' do
      allow(permissions).to receive(:can_write_to_active_space?).and_return(false)
      expect { action.assign(app, account) }.to raise_error(AppAssignServiceAccount::Unauthorized)
      expect(app.reload.service_account).to be_nil
    end

    it 'rejects an account in another space of the same organization' do
      other = ServiceAccountModel.create(name: 'reporting-reader', space: create(:space, organization: space.organization), status: 'ready')
      expect { action.assign(app, other) }.to raise_error(AppAssignServiceAccount::Conflict, /entitled/)
    end

    it 'is idempotent but requires explicit unbinding before replacement' do
      action.assign(app, account)
      action.assign(app, account)
      other = ServiceAccountModel.create(name: 'reporting-reader', space: space, status: 'ready')
      expect { action.assign(app, other) }.to raise_error(AppAssignServiceAccount::Conflict, /already assigned/)
      expect(app.reload.service_account).to eq(account)
    end

    it 'allows an app writer to unbind' do
      app.update(service_account: account)
      action.assign(app, nil)
      expect(app.reload.service_account).to be_nil
    end

    it 'rejects disabled and unprovisioned accounts' do
      account.update(enabled: false)
      expect { action.assign(app, account) }.to raise_error(AppAssignServiceAccount::Conflict, /not ready/)
      account.update(enabled: true, status: 'reserved')
      expect { action.assign(app, account) }.to raise_error(AppAssignServiceAccount::Conflict, /not ready/)
    end

    it 'serializes concurrent first binds to two apps into a single provisioning job', isolation: :truncation do
      account.update(status: 'reserved')
      other_app = create(:app_model, space: space)
      ids = [app.guid, other_app.guid]
      writer = create(:user)
      space.organization.add_user(writer)
      space.add_developer(writer)
      permission_queryer = Permissions.new(writer)
      permission_checks = Queue.new
      continue_assignments = Queue.new
      allow(permission_queryer).to receive(:can_write_to_active_space?).and_wrap_original do |method, *args|
        result = method.call(*args)
        # Both transactions must read before either locks the shared account. On MySQL,
        # this establishes repeatable-read snapshots that cannot see the other job.
        permission_checks << true
        continue_assignments.pop
        result
      end
      threads = ids.map do |guid|
        Thread.new do
          AppAssignServiceAccount.new(permission_queryer).assign(AppModel.first(guid: guid), ServiceAccountModel.first(guid: account.guid), provision: true)
        end
      end
      Timeout.timeout(10) { ids.size.times { permission_checks.pop } }
      ids.size.times { continue_assignments << true }
      jobs = threads.map(&:value)
      expect(jobs.map(&:guid).uniq.size).to eq(1)
      expect(PollableJobModel.where(resource_guid: account.guid).count).to eq(1)
      expect(AppModel.where(guid: ids).select_map(:service_account_guid)).to eq([account.guid, account.guid])
    end
  end
end
