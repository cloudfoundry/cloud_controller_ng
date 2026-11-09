require 'spec_helper'

RSpec.describe 'Organization service account prefixes' do
  let(:user) { create(:user) }
  let(:org) { create(:organization) }
  let(:admin_header) { admin_headers_for(user) }

  def create_org(name, prefix)
    post '/v3/organizations', { name: name, service_account_prefix: prefix }.to_json, admin_header
  end

  def allocate_prefix(prefix, auth=admin_header)
    patch "/v3/organizations/#{org.guid}", { service_account_prefix: prefix }.to_json, auth
  end

  it 'allows an admin to allocate a prefix at creation and records it in the audit event' do
    create_org('Payments', 'acme-payments')

    expect(last_response.status).to eq(201)
    expect(parsed_response['service_account_prefix']).to eq('acme-payments')
    created_guid = parsed_response['guid']
    event = VCAP::CloudController::Event.first(type: 'audit.organization.create', actee: created_guid)
    expect(event.metadata.dig('request', 'service_account_prefix')).to eq('acme-payments')

    get "/v3/organizations/#{created_guid}", nil, admin_header
    expect(parsed_response['service_account_prefix']).to eq('acme-payments')
    get '/v3/organizations', nil, admin_header
    expect(parsed_response['resources'].find { |resource| resource['guid'] == created_guid }['service_account_prefix']).to eq('acme-payments')
  end

  it 'leaves ordinary org creation available without generating a prefix' do
    post '/v3/organizations', { name: 'Ordinary Org' }.to_json, admin_header

    expect(last_response.status).to eq(201)
    expect(parsed_response).to include('service_account_prefix' => nil)
  end

  it 'accepts an explicitly unset prefix on creation' do
    create_org('Ordinary Org', nil)

    expect(last_response.status).to eq(201)
    expect(parsed_response).to include('service_account_prefix' => nil)
  end

  it 'allocates once on an existing org and preserves the prefix across rename and metadata updates' do
    allocate_prefix('acme-payments')
    expect(last_response.status).to eq(200)
    expect(parsed_response['service_account_prefix']).to eq('acme-payments')
    event = VCAP::CloudController::Event.first(type: 'audit.organization.update', actee: org.guid)
    expect(event.metadata.dig('request', 'service_account_prefix')).to eq('acme-payments')

    allocate_prefix('acme-payments')
    expect(last_response.status).to eq(200)
    patch "/v3/organizations/#{org.guid}", { name: 'Renamed', metadata: { labels: { team: 'payments' } } }.to_json, admin_header
    expect(last_response.status).to eq(200)
    expect(parsed_response).to include('name' => 'Renamed', 'service_account_prefix' => 'acme-payments')
  end

  ['different-prefix', nil].each do |replacement|
    it "rejects changing an allocated prefix to #{replacement.inspect} atomically" do
      allocate_prefix('acme-payments')
      expect(last_response.status).to eq(200)

      patch "/v3/organizations/#{org.guid}", { name: 'Must not change', service_account_prefix: replacement }.to_json, admin_header

      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to include('immutable')
      expect(org.reload.name).not_to eq('Must not change')
      get "/v3/organizations/#{org.guid}", nil, admin_header
      expect(parsed_response['service_account_prefix']).to eq('acme-payments')
    end
  end

  it 'rejects a prefix already allocated to another org on creation or update' do
    create_org('First Org', 'acme-payments')
    expect(last_response.status).to eq(201)

    expect { create_org('Second Org', 'acme-payments') }.not_to change(VCAP::CloudController::Organization, :count)
    expect(last_response.status).to eq(422)
    expect(parsed_response.dig('errors', 0, 'detail')).to include('already reserved')
    allocate_prefix('acme-payments')
    expect(last_response.status).to eq(422)
    allocate_prefix('available-prefix')
    expect(last_response.status).to eq(200)
  end

  it 'retains a prefix reservation after org deletion' do
    allocate_prefix('acme-payments')
    expect(last_response.status).to eq(200)
    expect(VCAP::CloudController::Organization.db[:service_account_prefixes].where(prefix: 'acme-payments').count).to eq(1)
    delete "/v3/organizations/#{org.guid}", nil, admin_header
    expect(last_response.status).to eq(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)
    expect(VCAP::CloudController::Organization.first(guid: org.guid)).to be_nil
    expect(VCAP::CloudController::Organization.db[:service_account_prefixes].where(prefix: 'acme-payments').count).to eq(1)

    create_org('Replacement Org', 'acme-payments')
    expect(last_response.status).to eq(422), last_response.body
    expect(parsed_response.dig('errors', 0, 'detail')).to include('already reserved')
  end

  ['abc', 'a-1', '123', 'a' * 63].each do |prefix|
    it "accepts the RFC label #{prefix.inspect}" do
      create_org('Valid Org', prefix)

      expect(last_response.status).to eq(201)
      expect(parsed_response['service_account_prefix']).to eq(prefix)
    end
  end

  ['', 'ab', 'a' * 64, 'Upper', '-abc', 'abc-', 'a.b', 'a_b', 'abc def', "abc\n", 'café', 123, false, {}].each do |prefix|
    it "rejects the invalid prefix #{prefix.inspect} on create and update" do
      create_org('Invalid Org', prefix)
      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to match(/Service account prefix/i)

      allocate_prefix(prefix)
      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to match(/Service account prefix/i)
    end
  end

  it 'does not let an org manager allocate a prefix or combine it with another update' do
    org.add_user(user)
    org.add_manager(user)
    auth = headers_for(user)

    patch "/v3/organizations/#{org.guid}", { name: 'Must not change', service_account_prefix: 'acme-payments' }.to_json, auth

    expect(last_response.status).to eq(403)
    expect(org.reload.name).not_to eq('Must not change')
    allocate_prefix('acme-payments')
    expect(last_response.status).to eq(200)
    allocate_prefix('acme-payments', auth)
    expect(last_response.status).to eq(403)
  end

  it 'does not let self-service org creators allocate a prefix' do
    create(:feature_flag, name: 'user_org_creation', enabled: true)
    uaa_client = instance_double(VCAP::CloudController::UaaClient)
    allow(CloudController::DependencyLocator.instance).to receive(:uaa_username_lookup_client).and_return(uaa_client)
    allow(uaa_client).to receive(:usernames_for_ids).with([user.guid]).and_return({ user.guid => 'creator' })

    expect do
      post '/v3/organizations', { name: 'Self Service', service_account_prefix: 'acme-payments' }.to_json, headers_for(user)
    end.not_to change(VCAP::CloudController::Organization, :count)
    expect(last_response.status).to eq(403)

    post '/v3/organizations', { name: 'Self Service' }.to_json, headers_for(user)
    expect(last_response.status).to eq(201)
    expect(parsed_response).to include('service_account_prefix' => nil)
  end
end
