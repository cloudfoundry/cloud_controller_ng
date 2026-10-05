require 'spec_helper'

RSpec.describe 'Service accounts' do
  let(:org) { create(:organization) }
  let(:space) { create(:space, organization: org) }
  let(:user) { create(:user) }
  let(:body) { { name: 'payments-worker', relationships: { space: { data: { guid: space.guid } } } } }

  def headers(role)
    set_user_with_header_as_role(role: role, org: org, space: space, user: user)
  end

  it 'allows a space manager to reserve an identity without provisioning a client' do
    post '/v3/service_accounts', body.to_json, headers('space_manager')

    expect(last_response.status).to eq(201)
    result = Oj.load(last_response.body)
    expect(result).to include('name' => 'payments-worker', 'status' => 'reserved', 'enabled' => true,
                              'client_id' => 'cf:service-account:payments-worker', 'certificate_dns_san' => 'payments-worker.svc.identity')
    expect(result.dig('relationships', 'space', 'data', 'guid')).to eq(space.guid)
    expect(VCAP::CloudController::ServiceAccountModel.where(guid: result['guid']).first.space_guid).to eq(space.guid)
  end

  it 'allows a platform administrator to create an account' do
    post '/v3/service_accounts', body.to_json, headers('admin')
    expect(last_response.status).to eq(201)
  end

  it 'denies a space developer account-creation authority' do
    post '/v3/service_accounts', body.to_json, headers('space_developer')
    expect(last_response.status).to eq(403)
    expect(VCAP::CloudController::ServiceAccountModel.count).to eq(0)
  end

  it 'rejects invalid names without normalizing them' do
    post '/v3/service_accounts', body.merge(name: 'Payments').to_json, headers('admin')
    expect(last_response.status).to eq(422)
  end

  it 'rejects caller-supplied identity and provisioning fields' do
    post '/v3/service_accounts', body.merge(client_id: 'attacker', status: 'ready').to_json, headers('admin')
    expect(last_response.status).to eq(422)
  end

  it 'rejects malformed relationship bodies' do
    post '/v3/service_accounts', { name: 'payments-worker', relationships: nil }.to_json, headers('admin')
    expect(last_response.status).to eq(422)
  end

  it 'returns conflict for a permanently reserved name' do
    account = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    account.destroy
    post '/v3/service_accounts', body.to_json, headers('admin')
    expect(last_response.status).to eq(409)
  end

  it 'denies creation in a suspended organization' do
    org.update(status: 'suspended')
    post '/v3/service_accounts', body.to_json, headers('space_manager')
    expect(last_response.status).to eq(403)
  end

  it 'allows an owning-space member to read the account' do
    account = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    get "/v3/service_accounts/#{account.guid}", nil, headers('space_developer')

    expect(last_response.status).to eq(200)
    expect(Oj.load(last_response.body)['guid']).to eq(account.guid)
  end

  it 'hides accounts from developers in another space of the same organization' do
    account = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: create(:space, organization: org))
    get "/v3/service_accounts/#{account.guid}", nil, headers('space_developer')
    expect(last_response.status).to eq(404)
  end

  it 'rejects unauthenticated access' do
    post '/v3/service_accounts', body.to_json, base_json_headers
    expect(last_response.status).to eq(401)
  end

  it 'rejects an organization ownership relationship' do
    post '/v3/service_accounts', { name: 'payments-worker', relationships: { organization: { data: { guid: org.guid } } } }.to_json, headers('admin')
    expect(last_response.status).to eq(422)
  end

  it 'denies creation in a suspended space' do
    space.update(status: VCAP::CloudController::Space::SUSPENDED)
    post '/v3/service_accounts', body.to_json, headers('space_manager')
    expect(last_response.status).to eq(403)
  end

  it 'creates and updates description and metadata using normal merge/remove semantics' do
    auth = headers('space_manager')
    post '/v3/service_accounts', body.merge(description: 'Batch payments', metadata: { labels: { team: 'payments' }, annotations: { note: 'original' } }).to_json, auth
    expect(last_response.status).to eq(201)
    result = Oj.load(last_response.body)
    expect(result['description']).to eq('Batch payments')
    patch "/v3/service_accounts/#{result['guid']}", { description: 'Revised', metadata: { labels: { team: nil, owner: 'finance' } } }.to_json, auth
    expect(last_response.status).to eq(200)
    result = Oj.load(last_response.body)
    expect(result['description']).to eq('Revised')
    expect(result['metadata']).to eq('labels' => { 'owner' => 'finance' }, 'annotations' => { 'note' => 'original' })
  end

  it 'lists only readable accounts with pagination and space/name filters' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    VCAP::CloudController::ServiceAccountModel.create(name: 'hidden-worker', space: create(:space))
    get '/v3/service_accounts?per_page=1&names=payments-worker', nil, headers('space_developer')
    expect(last_response.status).to eq(200)
    result = Oj.load(last_response.body)
    expect(result.dig('pagination', 'total_results')).to eq(1)
    expect(result['resources'].map { |r| r['guid'] }).to eq([own.guid])
    get "/v3/service_accounts?space_guids=#{space.guid}", nil, headers('admin')
    expect(Oj.load(last_response.body)['resources'].map { |r| r['guid'] }).to eq([own.guid])
  end

  it 'lists assigned apps only for account readers' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    app = create(:app_model, space: space, service_account: own)
    get "/v3/service_accounts/#{own.guid}/apps", nil, headers('space_auditor')
    expect(last_response.status).to eq(200)
    expect(Oj.load(last_response.body)['resources'].map { |r| r['guid'] }).to eq([app.guid])
  end

  it 'denies developers updates and hides unreadable resources' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    patch "/v3/service_accounts/#{own.guid}", { description: 'unauthorized' }.to_json, headers('space_developer')
    expect(last_response.status).to eq(403)
    hidden = VCAP::CloudController::ServiceAccountModel.create(name: 'hidden-worker', space: create(:space))
    patch "/v3/service_accounts/#{hidden.guid}", { description: 'unauthorized' }.to_json, headers('space_manager')
    expect(last_response.status).to eq(404)
  end

  %i[name relationships status client_id certificate_dns_san].each do |key|
    it "rejects mutation of platform-owned #{key}" do
      own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
      patch "/v3/service_accounts/#{own.guid}", { key => 'injected' }.to_json, headers('space_manager')
      expect(last_response.status).to eq(422)
    end
  end

  it 'rejects invalid metadata and list parameters' do
    post '/v3/service_accounts', body.merge(metadata: { labels: { 'invalid/key/key' => 'value' } }).to_json, headers('admin')
    expect(last_response.status).to eq(422)
    get '/v3/service_accounts?unknown=value', nil, headers('admin')
    expect(last_response.status).to eq(400)
  end
end
