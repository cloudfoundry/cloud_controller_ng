require 'spec_helper'

RSpec.describe 'Service accounts' do
  let(:org) { create(:organization, service_account_prefix: 'test-team') }
  let(:space) { create(:space, organization: org) }
  let(:user) { create(:user) }
  let(:body) { { name: 'payments-worker', relationships: { space: { data: { guid: space.guid } } } } }

  def headers(role)
    set_user_with_header_as_role(role: role, org: org, space: space, user: user)
  end

  it 'allows a space developer to reserve an identity without provisioning a client' do
    post '/v3/service_accounts', body.to_json, headers('space_developer')

    expect(last_response.status).to eq(201)
    result = Oj.load(last_response.body)
    expect(result).to include('name' => 'payments-worker', 'status' => 'reserved', 'enabled' => true,
                              'client_id' => 'cf:service-account:test-team:payments-worker', 'certificate_dns_san' => 'payments-worker.test-team.svc.identity')
    expect(result.dig('relationships', 'organization', 'data', 'guid')).to eq(org.guid)
    expect(result.dig('relationships', 'spaces', 'data')).to eq([{ 'guid' => space.guid }])
    event = VCAP::CloudController::Event.first(type: 'audit.service_account.create', actee: result['guid'])
    expect(event).not_to be_nil
    expect(event.actor).to eq(user.guid)
    expect(event.space_guid).to eq(space.guid)
  end

  it 'allows a platform administrator to create an account' do
    post '/v3/service_accounts', body.to_json, headers('admin')
    expect(last_response.status).to eq(201)
  end

  context 'weekly creation budget' do
    before { TestConfig.override(service_account_creation_limit: 1) }

    it 'limits a principal across spaces without refunding deleted accounts' do
      auth = headers('space_developer')
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(201)
      VCAP::CloudController::ServiceAccountModel.first.destroy
      other_space = create(:space, organization: org)
      other_space.add_developer(user)
      other_body = { name: 'other-worker', relationships: { space: { data: { guid: other_space.guid } } } }

      post '/v3/service_accounts', other_body.to_json, auth

      expect(last_response.status).to eq(429)
      expect(Oj.load(last_response.body).dig('errors', 0, 'title')).to eq('CF-ServiceAccountCreationLimitExceeded')
      expect(VCAP::CloudController::ServiceAccountModel.count).to eq(0)
    end

    it 'uses a rolling seven-day window' do
      auth = headers('space_developer')
      Timecop.freeze(Time.utc(2026, 10, 1)) do
        post '/v3/service_accounts', body.to_json, auth
        expect(last_response.status).to eq(201)
      end
      Timecop.freeze(Time.utc(2026, 10, 7, 23, 59, 59)) do
        post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, auth
        expect(last_response.status).to eq(429)
      end
      Timecop.freeze(Time.utc(2026, 10, 8)) do
        post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, auth
        expect(last_response.status).to eq(201)
      end
    end

    it 'does not consume budget on a failed creation' do
      auth = headers('space_developer')
      VCAP::CloudController::ServiceAccountModel.create(name: body[:name], space: space)
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(409)
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, auth
      expect(last_response.status).to eq(201)
      post '/v3/service_accounts', body.merge(name: 'third-worker').to_json, auth
      expect(last_response.status).to eq(429)
    end

    it 'does not share budget between principals' do
      post '/v3/service_accounts', body.to_json, headers('space_developer')
      expect(last_response.status).to eq(201)
      other_user = create(:user)
      auth = set_user_with_header_as_role(role: 'space_developer', org: org, space: space, user: other_user)
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, auth
      expect(last_response.status).to eq(201)
    end

    it 'supports explicit unlimited configuration' do
      TestConfig.override(service_account_creation_limit: -1)
      auth = headers('space_developer')
      %w[first-worker second-worker].each do |name|
        post '/v3/service_accounts', body.merge(name: name).to_json, auth
        expect(last_response.status).to eq(201)
      end
    end

    it 'exempts platform admins even when the configured budget is zero' do
      TestConfig.override(service_account_creation_limit: 0)
      auth = headers('admin')
      %w[first-worker second-worker].each do |name|
        post '/v3/service_accounts', body.merge(name: name).to_json, auth
        expect(last_response.status).to eq(201)
      end
      post '/v3/service_accounts', body.to_json, headers('space_developer')
      expect(last_response.status).to eq(429)
    end

    it 'applies to non-admin automation clients and exempts admin automation' do
      user.update(is_oauth_client: true)
      org.add_user(user)
      space.add_developer(user)
      coder = CF::UAA::TokenCoder.new(audience_ids: TestConfig.config[:uaa][:resource_id], skey: TestConfig.config[:uaa][:symmetric_secret], pkey: nil)
      token = { client_id: user.guid, scope: %w[cloud_controller.read cloud_controller.write], jti: 'automation', iss: UAAIssuer::ISSUER }
      auth = base_json_headers('HTTP_AUTHORIZATION' => "bearer #{coder.encode(token)}")
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(201)
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, auth
      expect(last_response.status).to eq(429)
      token[:scope] << 'cloud_controller.admin'
      admin_auth = base_json_headers('HTTP_AUTHORIZATION' => "bearer #{coder.encode(token)}")
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, admin_auth
      expect(last_response.status).to eq(201)
    end
  end

  it 'allows a space developer account-creation authority' do
    post '/v3/service_accounts', body.to_json, headers('space_developer')
    expect(last_response.status).to eq(201)
    expect(VCAP::CloudController::ServiceAccountModel.count).to eq(1)
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
    post '/v3/service_accounts', body.to_json, headers('space_developer')
    expect(last_response.status).to eq(403)
  end

  it 'allows an entitled-space member to read the account' do
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
    post '/v3/service_accounts', body.to_json, headers('space_developer')
    expect(last_response.status).to eq(403)
  end

  it 'creates and updates description and metadata using normal merge/remove semantics' do
    auth = headers('space_developer')
    post '/v3/service_accounts', body.merge(description: 'Batch payments', metadata: { labels: { team: 'payments' }, annotations: { note: 'original' } }).to_json, auth
    expect(last_response.status).to eq(201)
    result = Oj.load(last_response.body)
    expect(result['description']).to eq('Batch payments')
    patch "/v3/service_accounts/#{result['guid']}", { description: 'Revised', metadata: { labels: { team: nil, owner: 'finance' } } }.to_json, auth
    expect(last_response.status).to eq(200)
    result = Oj.load(last_response.body)
    expect(result['description']).to eq('Revised')
    expect(result['metadata']).to eq('labels' => { 'owner' => 'finance' }, 'annotations' => { 'note' => 'original' })
    expect(VCAP::CloudController::Event.where(type: 'audit.service_account.update', actee: result['guid']).count).to eq(1)
  end

  it 'lists only readable accounts with pagination and space/name filters' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    VCAP::CloudController::ServiceAccountModel.create(name: 'hidden-worker', space: create(:space, :with_service_account_prefix))
    get '/v3/service_accounts?per_page=1&names=payments-worker', nil, headers('space_developer')
    expect(last_response.status).to eq(200)
    result = Oj.load(last_response.body)
    expect(result.dig('pagination', 'total_results')).to eq(1)
    expect(result['resources'].pluck('guid')).to eq([own.guid])
    get "/v3/service_accounts?space_guids=#{space.guid}", nil, headers('admin')
    expect(Oj.load(last_response.body)['resources'].pluck('guid')).to eq([own.guid])
  end

  it 'lists assigned apps only for account readers' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    app = create(:app_model, space: space, service_account: own)
    get "/v3/service_accounts/#{own.guid}/apps", nil, headers('space_auditor')
    expect(last_response.status).to eq(200)
    expect(Oj.load(last_response.body)['resources'].pluck('guid')).to eq([app.guid])
    get "/v3/service_accounts/#{own.guid}/apps?names=missing-app", nil, headers('space_auditor')
    expect(Oj.load(last_response.body)['resources']).to eq([])
  end

  it 'loads presentation associations once per page rather than once per account' do
    auth = headers('admin')
    accounts = Array.new(3) do |index|
      entitled_space = create(:space, :with_service_account_prefix)
      account = VCAP::CloudController::ServiceAccountModel.create(name: "worker-#{index}", space: entitled_space)
      VCAP::CloudController::ServiceAccountLabelModel.create(resource_guid: account.guid, key_name: 'team', value: "team-#{index}")
      VCAP::CloudController::ServiceAccountAnnotationModel.create(resource_guid: account.guid, key_name: 'note', value: "note-#{index}")
      [account, entitled_space]
    end

    [1, 3].each do |per_page|
      %w[organizations spaces service_account_labels service_account_annotations].each do |table|
        expect do
          get "/v3/service_accounts?per_page=#{per_page}", nil, auth
        end.to have_queried_db_times(/SELECT .* FROM .#{table}. /i, 1)
      end

      expect(last_response.status).to eq(200)
      resources = Oj.load(last_response.body)['resources']
      expect(resources.size).to eq(per_page)
      resources.each do |resource|
        account, entitled_space = accounts.find { |entry| entry.first.guid == resource['guid'] }
        expect(resource.dig('relationships', 'organization', 'data', 'guid')).to eq(entitled_space.organization.guid)
        expect(resource.dig('relationships', 'spaces', 'data')).to eq([{ 'guid' => entitled_space.guid }])
        index = account.name.delete_prefix('worker-')
        expect(resource['metadata']).to eq({
                                            'labels' => { 'team' => "team-#{index}" },
                                            'annotations' => { 'note' => "note-#{index}" }
                                          })
      end
    end
  end

  it 'allows developer updates and hides unreadable resources' do
    own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
    patch "/v3/service_accounts/#{own.guid}", { description: 'unauthorized' }.to_json, headers('space_developer')
    expect(last_response.status).to eq(200)
    hidden = VCAP::CloudController::ServiceAccountModel.create(name: 'hidden-worker', space: create(:space, :with_service_account_prefix))
    patch "/v3/service_accounts/#{hidden.guid}", { description: 'unauthorized' }.to_json, headers('space_manager')
    expect(last_response.status).to eq(404)
  end

  %i[name relationships status client_id certificate_dns_san].each do |key|
    it "rejects mutation of platform-owned #{key}" do
      own = VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space)
      patch "/v3/service_accounts/#{own.guid}", { key => 'injected' }.to_json, headers('space_developer')
      expect(last_response.status).to eq(422)
    end
  end

  it 'rejects invalid metadata and list parameters' do
    post '/v3/service_accounts', body.merge(metadata: { labels: { 'invalid/key/key' => 'value' } }).to_json, headers('admin')
    expect(last_response.status).to eq(422)
    get '/v3/service_accounts?unknown=value', nil, headers('admin')
    expect(last_response.status).to eq(400)
  end

  context 'account lifecycle' do
    let(:account) { VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: space) }
    let(:clients) { instance_double(CF::UAA::Scim) }
    let(:provisioner) { VCAP::CloudController::ServiceAccountProvision.new(clients, identity_ca_ref: 'diego-instance-identity') }
    let(:account_path) { "/v3/service_accounts/#{account.guid}" }

    before do
      TestConfig.override(service_account_provisioning_enabled: true)
      CloudController::DependencyLocator.instance.register(:service_account_provisioner, provisioner)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      allow(clients).to receive(:delete)
    end

    it 'disables new authentication and enables again while retaining explicit principal roles' do
      provisioner.provision(account)
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      org.add_user(principal)
      space.add_developer(principal)
      registration = provisioner.send(:registration, account)
      allow(clients).to receive(:get).and_return(registration)
      auth = headers('space_developer')

      patch account_path, { enabled: false }.to_json, auth
      expect(last_response.status).to eq(202)
      expect(account.reload.enabled).to be(false)
      expect(Delayed::Worker.new.work_off).to eq([1, 0])
      expect(clients).to have_received(:delete).with(:client, account.client_id).once
      expect(account.reload.status).to eq('disabled')
      expect(principal.reload.spaces).to include(space)

      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      patch account_path, { enabled: true }.to_json, auth
      expect(last_response.status).to eq(202)
      expect(Delayed::Worker.new.work_off).to eq([1, 0])
      expect(account.reload.status).to eq('ready')
      expect(principal.reload.spaces).to include(space)
    end

    it 'deletes an unused account asynchronously and keeps its name permanently reserved' do
      provisioner.provision(account)
      allow(clients).to receive(:get).and_return(provisioner.send(:registration, account))
      guid = account.guid
      auth = headers('space_developer')
      delete account_path, nil, auth
      expect(last_response.status).to eq(202)
      expect(account.reload.status).to eq('deleting')
      expect(account.enabled).to be(false)
      expect(Delayed::Worker.new.work_off).to eq([1, 0])
      expect(VCAP::CloudController::ServiceAccountModel.first(guid: guid)).to be_nil
      expect(VCAP::CloudController::User.first(guid: account.client_id)).to be_nil
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(409)
    end

    it 'rejects deleting an account still assigned to an app' do
      create(:app_model, space: space, service_account: account)
      delete account_path, nil, headers('space_developer')
      expect(last_response.status).to eq(409)
      expect(account.reload.status).to eq('reserved')
      expect(Delayed::Job.count).to eq(0)
    end

    it 'denies auditor deletion and rejects non-boolean enabled values' do
      delete account_path, nil, headers('space_auditor')
      expect(last_response.status).to eq(403)
      patch account_path, { enabled: 'false' }.to_json, headers('space_developer')
      expect(last_response.status).to eq(422)
    end

    it 'refuses to delete an unmanaged colliding client' do
      allow(clients).to receive(:get).and_return('client_id' => account.client_id)
      delete account_path, nil, headers('space_developer')
      expect(last_response.status).to eq(202)
      expect(Delayed::Worker.new.work_off).to eq([0, 1])
      expect(clients).not_to have_received(:delete)
      expect(account.reload.status).to eq('failed')
    end

    it 'rejects deletion while an unbound app still has the account in a running launch snapshot' do
      app = create(:app_model, space: space)
      process = create(:process_model, app: app, state: 'STARTED')
      process.update(service_account_guid: account.guid, service_account_snapshot: true)
      delete account_path, nil, headers('space_developer')
      expect(last_response.status).to eq(409)
      expect(Delayed::Job.count).to eq(0)
    end

    it 'rejects deletion while an active task holds the account snapshot' do
      app = create(:app_model, space: space)
      create(:task_model, app: app, service_account_guid: account.guid, service_account_snapshot: true, state: 'RUNNING')
      delete account_path, nil, headers('space_developer')
      expect(last_response.status).to eq(409)
      expect(Delayed::Job.count).to eq(0)
    end
  end
end
