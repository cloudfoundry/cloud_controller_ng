require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Space-owned service account app assignments' do
    let(:space) { create(:space) }
    let(:app) { create(:app_model, space: space) }
    let(:account) { ServiceAccountModel.create(name: 'payments-worker', space: space) }

    it 'leaves existing apps unbound by default' do
      expect(app.service_account).to be_nil
    end

    it 'allows multiple apps in the owning space to share one account' do
      other_app = create(:app_model, space: space)
      app.update(service_account: account)
      other_app.update(service_account: account)
      expect(account.apps).to contain_exactly(app, other_app)
    end

    it 'supports unbinding' do
      app.update(service_account: account)
      app.update(service_account: nil)
      expect(app.reload.service_account).to be_nil
    end

    it 'rejects assignment from another space in the same organization' do
      other_space = create(:space, organization: space.organization)
      other_account = ServiceAccountModel.create(name: 'reporting-reader', space: other_space)
      expect { app.update(service_account: other_account) }.to raise_error(Sequel::ValidationFailed, /owning space/)
      expect(app.reload.service_account).to be_nil
    end

    it 'rejects moving a bound app to another space' do
      app.update(service_account: account)
      expect { app.update(space: create(:space, organization: space.organization)) }.to raise_error(Sequel::ValidationFailed, /owning space/)
      expect(app.reload.space).to eq(space)
    end

    it 'does not permit changing an account owner space' do
      expect { account.update(space: create(:space)) }.to raise_error(Sequel::ValidationFailed, /immutable/)
      expect(account.reload.space).to eq(space)
    end

    it 'prevents deleting a referenced account' do
      app.update(service_account: account)
      expect { account.db.transaction(savepoint: true) { account.destroy } }.to raise_error(Sequel::ForeignKeyConstraintViolation)
    end
  end
end
