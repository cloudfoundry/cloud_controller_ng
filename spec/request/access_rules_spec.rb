require 'spec_helper'

RSpec.describe 'Access Rules' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  let(:mtls_domain) do
    VCAP::CloudController::PrivateDomain.make(
      owning_organization: org,
      enforce_access_rules: true,
      access_rules_scope: 'space'
    )
  end
  let(:regular_domain) do
    VCAP::CloudController::PrivateDomain.make(owning_organization: org)
  end

  let(:mtls_route) { VCAP::CloudController::Route.make(space: space, domain: mtls_domain) }
  let(:regular_route) { VCAP::CloudController::Route.make(space: space, domain: regular_domain) }

  let(:valid_uuid) { '11111111-2222-3333-4444-555555555555' }

  def expected_rule_json(rule)
    {
      guid: rule.guid,
      created_at: iso8601,
      updated_at: iso8601,
      name: rule.name,
      selector: rule.selector,
      relationships: {
        route: { data: { guid: rule.route.guid } }
      },
      links: {
        self: { href: %r{/v3/access_rules/#{rule.guid}} },
        route: { href: %r{/v3/routes/#{rule.route.guid}} }
      }
    }
  end

  before do
    TestConfig.override(kubernetes: {})
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/access_rules' do
    let(:request_body) do
      {
        name: 'allow-frontend',
        selector: "cf:app:#{valid_uuid}",
        relationships: {
          route: { data: { guid: mtls_route.guid } }
        }
      }
    end

    context 'as admin' do
      it 'creates an access rule and returns 201' do
        post '/v3/access_rules', request_body.to_json, admin_header

        expect(last_response.status).to eq(201)
        parsed = Oj.load(last_response.body)
        expect(parsed['name']).to eq('allow-frontend')
        expect(parsed['selector']).to eq("cf:app:#{valid_uuid}")
        expect(parsed['relationships']['route']['data']['guid']).to eq(mtls_route.guid)
      end
    end

    context 'as space developer' do
      let(:user_headers) { headers_for(user) }

      it 'creates an access rule' do
        post '/v3/access_rules', request_body.to_json, user_headers

        expect(last_response.status).to eq(201)
      end
    end

    context 'when the domain does not have enforce_access_rules enabled' do
      let(:request_body) do
        {
          name: 'disallowed-rule',
          selector: "cf:app:#{valid_uuid}",
          relationships: {
            route: { data: { guid: regular_route.guid } }
          }
        }
      end

      it 'returns 422' do
        post '/v3/access_rules', request_body.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('enforce_access_rules')
      end
    end

    context 'when the route does not exist' do
      let(:request_body) do
        {
          name: 'bad-rule',
          selector: "cf:app:#{valid_uuid}",
          relationships: {
            route: { data: { guid: 'nonexistent-guid' } }
          }
        }
      end

      it 'returns 404' do
        post '/v3/access_rules', request_body.to_json, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'cf:any exclusivity' do
      before do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'existing-rule',
          selector: "cf:app:#{valid_uuid}",
          route_id: mtls_route.id
        )
      end

      it 'rejects cf:any when other rules exist' do
        post '/v3/access_rules', {
          name: 'any-rule',
          selector: 'cf:any',
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include("cf:any")
      end
    end

    context 'when a cf:any rule already exists' do
      before do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'any-rule',
          selector: 'cf:any',
          route_id: mtls_route.id
        )
      end

      it 'rejects adding a specific selector' do
        post '/v3/access_rules', {
          name: 'specific-rule',
          selector: "cf:space:#{valid_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include("cf:any")
      end
    end

    context 'duplicate name per route' do
      before do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'allow-frontend',
          selector: "cf:app:#{valid_uuid}",
          route_id: mtls_route.id
        )
      end

      it 'returns 422' do
        other_uuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        post '/v3/access_rules', {
          name: 'allow-frontend',
          selector: "cf:space:#{other_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('allow-frontend')
      end
    end

    context 'duplicate selector per route' do
      before do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'first-rule',
          selector: "cf:app:#{valid_uuid}",
          route_id: mtls_route.id
        )
      end

      it 'returns 422' do
        post '/v3/access_rules', {
          name: 'second-rule',
          selector: "cf:app:#{valid_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
      end
    end

    context 'invalid selector format' do
      it 'returns 422' do
        post '/v3/access_rules', {
          name: 'bad-rule',
          selector: 'not-valid',
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('selector')
      end
    end
  end

  describe 'GET /v3/access_rules/:guid' do
    let!(:access_rule) do
      VCAP::CloudController::RouteAccessRule.create(
        guid: SecureRandom.uuid,
        name: 'allow-frontend',
        selector: "cf:app:#{valid_uuid}",
        route_id: mtls_route.id
      )
    end

    it 'returns the access rule' do
      get "/v3/access_rules/#{access_rule.guid}", nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      expect(parsed['guid']).to eq(access_rule.guid)
      expect(parsed['name']).to eq('allow-frontend')
      expect(parsed['selector']).to eq("cf:app:#{valid_uuid}")
    end

    context 'when the access rule does not exist' do
      it 'returns 404' do
        get '/v3/access_rules/nonexistent-guid', nil, admin_header

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'GET /v3/access_rules' do
    let!(:rule1) do
      VCAP::CloudController::RouteAccessRule.create(
        guid: SecureRandom.uuid,
        name: 'rule-one',
        selector: "cf:app:#{valid_uuid}",
        route_id: mtls_route.id
      )
    end
    let!(:rule2) do
      VCAP::CloudController::RouteAccessRule.create(
        guid: SecureRandom.uuid,
        name: 'rule-two',
        selector: 'cf:any',
        route_id: VCAP::CloudController::Route.make(space: space, domain: mtls_domain).id
      )
    end

    it 'lists all accessible access rules' do
      get '/v3/access_rules', nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      guids = parsed['resources'].map { |r| r['guid'] }
      expect(guids).to include(rule1.guid, rule2.guid)
    end

    it 'filters by route_guids' do
      get "/v3/access_rules?route_guids=#{mtls_route.guid}", nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      guids = parsed['resources'].map { |r| r['guid'] }
      expect(guids).to include(rule1.guid)
      expect(guids).not_to include(rule2.guid)
    end

    it 'filters by names' do
      get '/v3/access_rules?names=rule-one', nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      expect(parsed['resources'].length).to eq(1)
      expect(parsed['resources'][0]['name']).to eq('rule-one')
    end

    it 'filters by selectors' do
      get '/v3/access_rules?selectors=cf:any', nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      expect(parsed['resources'].length).to eq(1)
      expect(parsed['resources'][0]['selector']).to eq('cf:any')
    end
  end

  describe 'DELETE /v3/access_rules/:guid' do
    let!(:access_rule) do
      VCAP::CloudController::RouteAccessRule.create(
        guid: SecureRandom.uuid,
        name: 'to-delete',
        selector: "cf:app:#{valid_uuid}",
        route_id: mtls_route.id
      )
    end

    it 'deletes the access rule and returns 204' do
      delete "/v3/access_rules/#{access_rule.guid}", nil, admin_header

      expect(last_response.status).to eq(204)
      expect(VCAP::CloudController::RouteAccessRule.find(guid: access_rule.guid)).to be_nil
    end

    context 'when the access rule does not exist' do
      it 'returns 404' do
        delete '/v3/access_rules/nonexistent-guid', nil, admin_header

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'PATCH /v3/access_rules/:guid (metadata update)' do
    let!(:access_rule) do
      VCAP::CloudController::RouteAccessRule.create(
        guid: SecureRandom.uuid,
        name: 'patchable',
        selector: "cf:app:#{valid_uuid}",
        route_id: mtls_route.id
      )
    end

    it 'returns 200' do
      patch "/v3/access_rules/#{access_rule.guid}", {
        metadata: { labels: { env: 'production' } }
      }.to_json, admin_header

      expect(last_response.status).to eq(200)
    end

    context 'when the access rule does not exist' do
      it 'returns 404' do
        patch '/v3/access_rules/nonexistent-guid', {}.to_json, admin_header

        expect(last_response.status).to eq(404)
      end
    end
  end
end
