require 'spec_helper'
require 'actions/service_account_provision'
require 'jobs/v3/service_account_provision' if File.exist?('app/jobs/v3/service_account_provision.rb')

module VCAP::CloudController
  RSpec.describe 'Service account provisioning job', job_context: :worker do
    let(:account) { ServiceAccountModel.create(name: 'payments-worker', space: create(:space)) }
    let(:clients) { instance_double(CF::UAA::Scim) }
    let(:provisioner) { ServiceAccountProvision.new(clients, identity_ca: 'worker-only-ca') }
    let(:locator) { CloudController::DependencyLocator.instance }
    let(:job) { Jobs::V3.const_get(:ServiceAccountProvision).new(account.guid) }

    before do
      locator.register(:service_account_provisioner, provisioner)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
    end

    it 'is serializable without credentials and resolves provisioning dependencies in the worker' do
      serialized = YAML.dump(job)
      expect(serialized).not_to include('worker-only-ca')
      expect(serialized).not_to include('CF::UAA::Scim')
      restored = YAML.unsafe_load(serialized)

      restored.perform

      expect(account.reload.status).to eq('ready')
      expect(User.first(guid: account.client_id).is_oauth_client).to be(true)
      expect(restored.resource_guid).to eq(account.guid)
      expect(restored.resource_type).to eq('service_account')
      expect(restored.display_name).to eq('service_account.provision')
      expect(restored).to be_a_valid_job
      expect(restored.max_attempts).to eq(3)
    end

    it 'propagates transient errors for retry and reconciles the persisted failed account on the next attempt' do
      allow(clients).to receive(:add).and_raise(CF::UAA::BadTarget, 'unavailable')
      expect { job.perform }.to raise_error(CF::UAA::BadTarget)
      expect(account.reload.status).to eq('failed')
      expect(User.first(guid: account.client_id)).to be_nil

      allow(clients).to receive(:add)
      job.perform

      expect(account.reload.status).to eq('ready')
    end

    it 'does not contact UAA or create a principal if the account was disabled while queued' do
      queued = job
      account.update(enabled: false)
      expect(clients).not_to receive(:get)
      expect { queued.perform }.to raise_error(ServiceAccountProvision::Conflict, /disabled/)
      expect(User.first(guid: account.client_id)).to be_nil
    end

    it 'does not contact UAA if the account was deleted while queued' do
      queued = job
      account.destroy
      expect(clients).not_to receive(:get)
      expect { queued.perform }.to raise_error(CloudController::Errors::ApiError, /could not be found/)
    end

    it 'fails closed when worker provisioning has not been configured' do
      locator.register(:service_account_provisioner, nil)
      expect(clients).not_to receive(:get)
      expect { job.perform }.to raise_error(/service account provisioning is not configured/)
      expect(account.reload.status).to eq('reserved')
      expect(User.first(guid: account.client_id)).to be_nil
    end
  end
end
