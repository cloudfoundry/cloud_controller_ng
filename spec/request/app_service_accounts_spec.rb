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
