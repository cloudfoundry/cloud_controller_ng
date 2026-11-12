require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account registry' do
    let(:space) { create(:space, organization: create(:organization, service_account_prefix: 'registry-team')) }
    let(:model) { VCAP::CloudController.const_get(:ServiceAccountModel) }

    def reserve(name, owner=space)
      model.create(name: name, space: owner)
    end

    it 'reserves an org-owned qualified identity without provisioning authentication' do
      account = reserve('payments-worker')

      expect(account.guid).not_to be_empty
      expect(account.organization).to eq(space.organization)
      expect(account.entitled_spaces).to contain_exactly(space)
      expect(account.client_id).to eq('cf:service-account:registry-team:payments-worker')
      expect(account.certificate_dns_san).to eq('payments-worker.registry-team.svc.identity')
      expect(account.enabled).to be(true)
      expect(account.status).to eq('reserved')
    end

    it 'accepts canonical labels at both length boundaries' do
      expect(reserve('a-b').name).to eq('a-b')
      expect(reserve('a' * 63).name).to eq('a' * 63)
    end

    ['', 'ab', 'a' * 64, '-worker', 'worker-', 'Worker', 'work_er',
     'work.er', "worker\n", 'wörker', 'work%65r', 'work:er', '*worker'].each do |name|
      it "rejects noncanonical label #{name.inspect}" do
        expect { reserve(name) }.to raise_error(Sequel::ValidationFailed, /name/)
      end
    end

    it 'enforces org-local uniqueness across spaces in the database' do
      account = reserve('payments-worker')
      other_owner = create(:space, organization: space.organization)

      expect { reserve(account.name, other_owner) }.to raise_error(Sequel::ValidationFailed, /name/)
      expect do
        model.db.transaction(savepoint: true) do
          # Deliberately bypass model validation to exercise the database constraint.
          model.dataset.insert(account.values.except(:id, :guid).merge(guid: SecureRandom.uuid)) # rubocop:disable Rails/SkipsModelValidations
        end
      end.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'does not permit changing the identity name' do
      account = reserve('payments-worker')

      expect { account.update(name: 'reporting-reader') }.to raise_error(Sequel::ValidationFailed, /immutable/)
      expect(account.reload.name).to eq('payments-worker')
    end

    it 'retains the name after deletion within the owning org' do
      account = reserve('payments-worker')
      account.destroy

      expect(model.where(guid: account.guid).first).to be_nil
      expect { reserve('payments-worker', create(:space, organization: space.organization)) }.to raise_error(Sequel::ValidationFailed, /name/)
    end

    it 'rejects accounts without an allocated organization prefix' do
      expect { reserve('worker-app', create(:space)) }.to raise_error(Sequel::ValidationFailed, /prefix/)
    end

    it 'rejects a prefix that does not belong to the owning organization' do
      expect do
        model.create(name: 'worker-app', space: space, identity_prefix: 'another-team')
      end.to raise_error(Sequel::ValidationFailed, /prefix/)
    end
  end
end
