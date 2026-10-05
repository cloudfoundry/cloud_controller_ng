require 'spec_helper'

RSpec.describe 'App service account relationship' do
  let(:space) { create(:space) }
  let(:user) { create(:user) }
  let(:app_model) { create(:app_model, space: space, desired_state: 'STARTED') }
  let(:account) { VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space, status: 'ready') }
  let(:path) { "/v3/apps/#{app_model.guid}/relationships/service_account" }

  def headers(role)
    set_user_with_header_as_role(role: role, org: space.organization, space: space, user: user)
  end

  it 'lets a developer bind a ready same-space account without restarting the app' do
    patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
    expect(last_response.status).to eq(200)
    expect(Oj.load(last_response.body)['data']).to eq('guid' => account.guid)
    expect(last_response.headers['X-Cf-Warnings']).to include('Restart')
    expect(app_model.reload.service_account).to eq(account)
    expect(app_model.desired_state).to eq('STARTED')
  end

  it 'shows an empty relationship for an unbound app' do
    get path, nil, headers('space_auditor')
    expect(last_response.status).to eq(200)
    expect(Oj.load(last_response.body)['data']).to be_nil
  end

  it 'denies an auditor assignment permission' do
    patch path, { data: { guid: account.guid } }.to_json, headers('space_auditor')
    expect(last_response.status).to eq(403)
    expect(app_model.reload.service_account).to be_nil
  end

  it 'denies a cross-space account even for an administrator' do
    other = VCAP::CloudController::ServiceAccountModel.create(name: 'reporting-reader', space: create(:space, organization: space.organization), status: 'ready')
    patch path, { data: { guid: other.guid } }.to_json, headers('admin')
    expect(last_response.status).to eq(409)
    expect(app_model.reload.service_account).to be_nil
  end

  it 'requires unbinding before replacing an account' do
    app_model.update(service_account: account)
    other = VCAP::CloudController::ServiceAccountModel.create(name: 'reporting-reader', space: space, status: 'ready')
    patch path, { data: { guid: other.guid } }.to_json, headers('space_developer')
    expect(last_response.status).to eq(409)
    expect(app_model.reload.service_account).to eq(account)
  end

  it 'supports explicit unbinding and returns restart guidance' do
    app_model.update(service_account: account)
    patch path, { data: nil }.to_json, headers('space_developer')
    expect(last_response.status).to eq(200)
    expect(app_model.reload.service_account).to be_nil
    expect(last_response.headers['X-Cf-Warnings']).to include('Restart')
  end

  it 'rejects assignment while the space is suspended' do
    space.update(status: VCAP::CloudController::Space::SUSPENDED)
    patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
    expect(last_response.status).to eq(403)
  end

  it 'rejects unprovisioned accounts rather than claiming successful binding' do
    account.update(status: 'reserved')
    patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
    expect(last_response.status).to eq(409)
  end

  context 'when asynchronous provisioning is enabled' do
    let(:clients) { instance_double(CF::UAA::Scim) }

    before do
      TestConfig.override(service_account_provisioning_enabled: true)
      CloudController::DependencyLocator.instance.register(
        :service_account_provisioner,
        VCAP::CloudController::ServiceAccountProvision.new(clients, identity_ca: 'identity-ca')
      )
      account.update(status: 'reserved')
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
    end

    it 'accepts desired binding and exposes one pollable provisioning job without restarting' do
      patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
      expect(last_response.status).to eq(202)
      location = last_response.headers['Location']
      expect(location).to include('/v3/jobs/')
      expect(app_model.reload.service_account_guid).to eq(account.guid)
      expect(app_model.desired_state).to eq('STARTED')
      expect(account.reload.status).to eq('reconciling')
      expect(VCAP::CloudController::User.first(guid: account.client_id)).to be_nil
      expect(clients).not_to have_received(:add)

      get URI(location).path, nil, headers('space_developer')
      expect(last_response.status).to eq(200)
      expect(Oj.load(last_response.body)).to include('state' => 'PROCESSING', 'operation' => 'service_account.provision')
      expect(Delayed::Worker.new.work_off).to eq([1, 0])
      expect(account.reload.status).to eq('ready')
      get URI(location).path, nil, headers('space_developer')
      expect(Oj.load(last_response.body)['state']).to eq('COMPLETE')
      expect(VCAP::CloudController::User.first(guid: account.client_id).spaces).to be_empty
    end

    it 'reuses the active job for repeated binding and another app sharing the account' do
      auth = headers('space_developer')
      patch path, { data: { guid: account.guid } }.to_json, auth
      location = last_response.headers['Location']
      patch path, { data: { guid: account.guid } }.to_json, auth
      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to eq(location)
      other_app = create(:app_model, space: space)
      patch "/v3/apps/#{other_app.guid}/relationships/service_account", { data: { guid: account.guid } }.to_json, auth
      expect(last_response.headers['Location']).to eq(location)
      expect(Delayed::Job.count).to eq(1)
    end

    it 'allows unbinding while queued and does not restore the assignment when provisioning finishes' do
      auth = headers('space_developer')
      patch path, { data: { guid: account.guid } }.to_json, auth
      patch path, { data: nil }.to_json, auth
      expect(last_response.status).to eq(200)
      Delayed::Worker.new.work_off
      expect(app_model.reload.service_account_guid).to be_nil
      expect(account.reload.status).to eq('ready')
    end

    %w[space_auditor space_manager].each do |role|
      it "does not queue provisioning for #{role}" do
        patch path, { data: { guid: account.guid } }.to_json, headers(role)
        expect(last_response.status).to eq(403)
        expect(Delayed::Job.count).to eq(0)
        expect(account.reload.status).to eq('reserved')
      end
    end

    it 'does not queue provisioning for a disabled account' do
      account.update(enabled: false)
      patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
      expect(last_response.status).to eq(409)
      expect(Delayed::Job.count).to eq(0)
    end

    it 'does not queue a cross-space account even for an administrator' do
      other = VCAP::CloudController::ServiceAccountModel.create(name: 'other-worker', space: create(:space))
      patch path, { data: { guid: other.guid } }.to_json, headers('admin')
      expect(last_response.status).to eq(409)
      expect(Delayed::Job.count).to eq(0)
    end

    it 'rolls back desired binding and state if enqueueing fails' do
      allow_any_instance_of(VCAP::CloudController::Jobs::Enqueuer).to receive(:enqueue_pollable).and_raise('queue unavailable')
      patch path, { data: { guid: account.guid } }.to_json, headers('space_developer')
      expect(last_response.status).to eq(500)
      expect(app_model.reload.service_account_guid).to be_nil
      expect(account.reload.status).to eq('reserved')
    end
  end

  [{}, { data: {} }, { data: { guid: nil } }, { data: { guid: 'x', name: 'injected' } }, { data: [] }].each do |body|
    it "rejects malformed relationship body #{body.inspect}" do
      patch path, body.to_json, headers('space_developer')
      expect(last_response.status).to eq(422)
    end
  end

  it 'hides apps outside the caller space' do
    other_app = create(:app_model, space: create(:space, organization: space.organization))
    get "/v3/apps/#{other_app.guid}/relationships/service_account", nil, headers('space_developer')
    expect(last_response.status).to eq(404)
  end
end
