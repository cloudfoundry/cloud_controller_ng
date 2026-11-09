require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account organization ownership' do
    let(:space) { create(:space) }

    it 'persists the immutable org owner and initial space entitlement at creation' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)

      expect(account.reload.organization).to eq(space.organization)
      expect(account.entitled_spaces).to contain_exactly(space)
      expect(account.client_id).to eq('cf:service-account:payments-worker')
      expect(account.certificate_dns_san).to eq('payments-worker.svc.identity')
    end

    it 'does not duplicate the initial entitlement when metadata or state changes' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)
      account.update(description: 'Batch processing', enabled: false)

      expect(account.reload.entitled_spaces).to contain_exactly(space)
    end

    it 'rejects changing the owning organization' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)
      other_org = create(:organization)

      expect { account.update(organization: other_org) }.to raise_error(Sequel::ValidationFailed, /organization.*immutable/)
      expect(account.reload.organization).to eq(space.organization)
    end

    it 'rejects creating an account whose initial space belongs to another org' do
      other_org = create(:organization)

      expect do
        ServiceAccountModel.create(name: 'payments-worker', space: space, organization: other_org)
      end.to raise_error(Sequel::ValidationFailed, /organization/)
      expect(ServiceAccountModel.count).to eq(0)
    end

    it 'removes entitlement rows when the account is deleted without deleting the space or org' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)
      account.destroy

      expect(ServiceAccountModel.db[:service_account_space_entitlements].where(service_account_guid: account.guid).count).to eq(0)
      expect(Space.first(guid: space.guid)).not_to be_nil
      expect(Organization.first(id: space.organization_id)).not_to be_nil
    end

    it 'refuses a cross-org entitlement even when the model association is used directly' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)
      expect { account.add_entitled_space(create(:space)) }.to raise_error(Sequel::ValidationFailed, /organization/)
    end

    it 'refuses starting a process after its desired account entitlement disappears' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space, status: 'ready')
      app = create(:app_model, space: space, service_account: account)
      process = create(:process_model, app: app, state: ProcessModel::STOPPED)
      account.remove_all_entitled_spaces
      expect { process.update(state: ProcessModel::STARTED) }.to raise_error(Sequel::ValidationFailed, /entitled/)
    end

    it 'measures known deletion counts and age buckets without assigning dates to historical reservations' do
      account = ServiceAccountModel.create(name: 'payments-worker', space: space)
      account.destroy
      stats = ServiceAccountModel.reservation_statistics
      expect(stats).to include(reserved_names: 1, deletions: 1, unknown_deletion_times: 0)
      expect(stats[:deletion_age_days]).to include('0-7' => 1)
    end

    it 'counts an orphan reservation as unknown even when another org uses the same local name' do
      other_org = create(:organization, service_account_prefix: 'stats-team')
      ServiceAccountModel.create(name: 'shared-name', space: create(:space, organization: other_org))
      ServiceAccountModel.db[:service_account_names].insert(name: 'shared-name', organization_id: space.organization_id) # rubocop:disable Rails/SkipsModelValidations -- Historical orphan fixture.
      expect(ServiceAccountModel.reservation_statistics[:unknown_deletion_times]).to eq(1)
    end
  end
end
