require 'spec_helper'
require 'actions/organization_delete'

module VCAP::CloudController
  RSpec.describe 'Org-owned service account lifecycle' do
    let(:space) { create(:space) }
    let(:org) { space.organization }
    let(:account) { ServiceAccountModel.create(name: 'shared-worker', space: space) }
    let(:actor) { UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'manager@example.com') }
    let(:space_delete) { SpaceDelete.new(actor, Repositories::ServiceEventRepository.new(actor)) }
    let(:org_delete) { OrganizationDelete.new(space_delete, actor) }
    let(:clients) { instance_double(CF::UAA::Scim) }
    let(:provisioner) { ServiceAccountProvision.new(clients, identity_ca_ref: 'diego-instance-identity') }

    before do
      TestConfig.override(kubernetes: {})
      CloudController::DependencyLocator.instance.register(:service_account_provisioner, provisioner)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      allow(clients).to receive(:delete)
    end

    it 'keeps the enabled account, principal and grants when its last space is deleted' do
      provisioner.provision(account)
      principal = User.first(guid: account.client_id)
      org.add_user(principal)
      app = create(:app_model, space: space, service_account: account)

      expect(space_delete.delete([space])).to be_empty

      expect(account.reload.organization).to eq(org)
      expect(account.enabled).to be(true)
      expect(account.status).to eq('ready')
      expect(account.entitled_spaces).to be_empty
      expect(account.space_guid).to be_nil
      expect(User.first(guid: principal.guid)).not_to be_nil
      expect(org.users_dataset.where(users__id: principal.id).any?).to be(true)
      expect(AppModel.first(guid: app.guid)).to be_nil
      expect(clients).not_to have_received(:delete)
    end

    it 'cleans up a zero-entitlement account on org deletion, retaining the parent after failure for retry' do
      account
      expect(space_delete.delete([space])).to be_empty
      allow(clients).to receive(:get).and_raise('UAA unavailable')

      expect(org_delete.delete([org]).map(&:message).join).to include('UAA unavailable')
      expect(Organization.first(id: org.id)).not_to be_nil
      expect(org.reload.status).to eq(Organization::DELETING)
      expect(account.reload.status).to eq('failed')

      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      expect(org_delete.delete([org])).to be_empty
      expect(ServiceAccountModel.first(guid: account.guid)).to be_nil
      expect(Organization.first(id: org.id)).to be_nil
    end

    it 'does not bypass shared-domain deletion guards when accounts mark an org deleting' do
      account
      domain = create(:private_domain, owning_organization: org)
      domain.add_shared_organization(create(:organization))
      expect(org_delete.delete([org]).map(&:message).join).to include('shared')
      expect(Organization.first(id: org.id)).not_to be_nil
      expect(PrivateDomain.first(guid: domain.guid)).not_to be_nil
    end
  end
end
