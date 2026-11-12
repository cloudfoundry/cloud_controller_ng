require 'spec_helper'
require 'actions/organization_delete'

module VCAP::CloudController
  RSpec.describe 'Org-owned service account lifecycle' do
    let(:space) { create(:space, organization: create(:organization, service_account_prefix: 'lifecycle-team')) }
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
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      org.add_user(principal)
      app = create(:app_model, space: space, service_account: account)

      expect(space_delete.delete([space])).to be_empty

      expect(account.reload.organization).to eq(org)
      expect(account.enabled).to be(true)
      expect(account.status).to eq('ready')
      expect(account.entitled_spaces).to be_empty
      expect(User.first(guid: principal.guid)).not_to be_nil
      expect(org.users_dataset.where(users__id: principal.id).any?).to be(true)
      expect(AppModel.first(guid: app.guid)).to be_nil
      expect(clients).not_to have_received(:delete)
    end

    it 'cleans up a zero-entitlement account on org deletion, retaining the parent after failure for retry' do
      provisioner.provision(account)
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

    it 'deletes an unused reservation without provisioning configuration and retains its deletion history' do
      guid = account.guid
      org_guid = org.guid
      locator = CloudController::DependencyLocator.instance
      expect(locator).not_to receive(:service_account_provisioner)

      expect(org_delete.delete([org])).to be_empty

      expect(ServiceAccountModel.first(guid: guid)).to be_nil
      expect(Organization.first(id: org.id)).to be_nil
      expect(ServiceAccountModel.db[:service_account_names].where(name: account.name, organization_id: org.id).first[:deleted_at]).not_to be_nil
      expect(ServiceAccountModel.db[:service_account_name_deletions].where(account_guid: guid, organization_guid: org_guid)).not_to be_empty
      expect(Event.where(type: 'audit.service_account.delete', actee: guid)).not_to be_empty
      expect(clients).not_to have_received(:get)
    end

    it 'retains a failed account and its org when provisioning configuration is unavailable' do
      account.update(status: 'failed')
      allow(CloudController::DependencyLocator.instance).to receive(:service_account_provisioner).and_raise('service account provisioning is not configured')

      expect(org_delete.delete([org]).map(&:message).join).to include('service account provisioning is not configured')

      expect(ServiceAccountModel.first(guid: account.guid)).not_to be_nil
      expect(org.reload.status).to eq(Organization::DELETING)
    end

    it 'does not locally delete a reservation with an active lifecycle job' do
      job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(Jobs::V3::ServiceAccountProvision.new(account.guid))
      expect(CloudController::DependencyLocator.instance).not_to receive(:service_account_provisioner)

      expect(org_delete.delete([org]).map(&:message).join).to include('operation is already in progress')

      expect(account.reload.status).to eq('reserved')
      expect(PollableJobModel.first(guid: job.guid)).not_to be_nil
      expect(org.reload.status).to eq(Organization::DELETING)
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
