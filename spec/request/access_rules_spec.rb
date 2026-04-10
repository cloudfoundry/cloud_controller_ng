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
        expect(last_response.body).to include('cf:any')
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
        expect(last_response.body).to include('cf:any')
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

    describe 'filtering by space_guids' do
      let(:other_org) { VCAP::CloudController::Organization.make }
      let(:other_space) { VCAP::CloudController::Space.make(organization: other_org) }
      let(:other_mtls_domain) do
        VCAP::CloudController::PrivateDomain.make(
          owning_organization: other_org,
          enforce_access_rules: true,
          access_rules_scope: 'space'
        )
      end
      let(:other_route) { VCAP::CloudController::Route.make(space: other_space, domain: other_mtls_domain) }
      let!(:rule_in_other_space) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'rule-in-other-space',
          selector: 'cf:any',
          route_id: other_route.id
        )
      end

      before do
        other_org.add_user(user)
        other_space.add_developer(user)
      end

      it 'filters by single space_guid' do
        get "/v3/access_rules?space_guids=#{space.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        guids = parsed['resources'].map { |r| r['guid'] }
        expect(guids).to include(rule1.guid, rule2.guid)
        expect(guids).not_to include(rule_in_other_space.guid)
      end

      it 'filters by multiple space_guids' do
        get "/v3/access_rules?space_guids=#{space.guid},#{other_space.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        guids = parsed['resources'].map { |r| r['guid'] }
        expect(guids).to include(rule1.guid, rule2.guid, rule_in_other_space.guid)
      end

      it 'combines space_guids with other filters' do
        get "/v3/access_rules?space_guids=#{space.guid}&names=rule-one", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        expect(parsed['resources'].length).to eq(1)
        expect(parsed['resources'][0]['guid']).to eq(rule1.guid)
        expect(parsed['resources'][0]['name']).to eq('rule-one')
      end

      it 'returns empty when space has no access rules' do
        empty_space = VCAP::CloudController::Space.make(organization: org)
        org.add_user(user)
        empty_space.add_developer(user)

        get "/v3/access_rules?space_guids=#{empty_space.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        expect(parsed['resources'].length).to eq(0)
      end
    end

    context 'with include=selector_resource' do
      let!(:app) { VCAP::CloudController::AppModel.make(space: space, name: 'frontend-app') }
      let!(:other_space) { VCAP::CloudController::Space.make(organization: org, name: 'other-space') }
      let!(:other_org) { VCAP::CloudController::Organization.make(name: 'other-org') }

      let!(:app_rule) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'app-rule',
          selector: "cf:app:#{app.guid}",
          route_id: mtls_route.id
        )
      end

      let!(:space_rule) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'space-rule',
          selector: "cf:space:#{other_space.guid}",
          route_id: mtls_route.id
        )
      end

      let!(:org_rule) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'org-rule',
          selector: "cf:org:#{other_org.guid}",
          route_id: mtls_route.id
        )
      end

      it 'includes resolved selector resources' do
        get '/v3/access_rules?include=selector_resource', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Check included structure
        expect(parsed['included']).to be_a(Hash)
        expect(parsed['included']['apps']).to be_an(Array)
        expect(parsed['included']['spaces']).to be_an(Array)
        expect(parsed['included']['organizations']).to be_an(Array)

        # Check app is included with full details
        app_included = parsed['included']['apps'].find { |a| a['guid'] == app.guid }
        expect(app_included).to be_present
        expect(app_included['name']).to eq('frontend-app')
        expect(app_included['guid']).to eq(app.guid)

        # Check space is included
        space_included = parsed['included']['spaces'].find { |s| s['guid'] == other_space.guid }
        expect(space_included).to be_present
        expect(space_included['name']).to eq('other-space')

        # Check org is included
        org_included = parsed['included']['organizations'].find { |o| o['guid'] == other_org.guid }
        expect(org_included).to be_present
        expect(org_included['name']).to eq('other-org')
      end

      it 'handles stale resources (missing GUIDs) gracefully' do
        stale_guid = '99999999-9999-9999-9999-999999999999'
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'stale-rule',
          selector: "cf:app:#{stale_guid}",
          route_id: mtls_route.id
        )

        get '/v3/access_rules?include=selector_resource', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Stale resource should not appear in included
        stale_app = parsed['included']['apps'].find { |a| a['guid'] == stale_guid }
        expect(stale_app).to be_nil
      end

      it 'includes only unique resources when multiple rules reference the same resource' do
        # Create another rule referencing the same app
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'another-app-rule',
          selector: "cf:app:#{app.guid}",
          route_id: VCAP::CloudController::Route.make(space: space, domain: mtls_domain).id
        )

        get '/v3/access_rules?include=selector_resource', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # App should appear only once
        app_count = parsed['included']['apps'].count { |a| a['guid'] == app.guid }
        expect(app_count).to eq(1)
      end

      it 'does not include resources for cf:any selectors' do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'any-rule',
          selector: 'cf:any',
          route_id: VCAP::CloudController::Route.make(space: space, domain: mtls_domain).id
        )

        get '/v3/access_rules?include=selector_resource', nil, admin_header

        expect(last_response.status).to eq(200)
        # Should succeed without error even with cf:any selector
      end
    end

    context 'with include=route' do
      let(:route2) { VCAP::CloudController::Route.make(space: space, domain: mtls_domain) }

      let!(:rule_on_route1) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'rule-on-route1',
          selector: 'cf:any',
          route_id: mtls_route.id
        )
      end

      let!(:rule_on_route2) do
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'rule-on-route2',
          selector: "cf:app:#{valid_uuid}",
          route_id: route2.id
        )
      end

      it 'includes route resources' do
        get '/v3/access_rules?include=route', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Check included structure
        expect(parsed['included']).to be_a(Hash)
        expect(parsed['included']['routes']).to be_an(Array)
        expect(parsed['included']['routes'].length).to be >= 2

        # Check routes are included with full details
        route1_included = parsed['included']['routes'].find { |r| r['guid'] == mtls_route.guid }
        expect(route1_included).to be_present
        expect(route1_included['guid']).to eq(mtls_route.guid)
        expect(route1_included['url']).to be_present

        route2_included = parsed['included']['routes'].find { |r| r['guid'] == route2.guid }
        expect(route2_included).to be_present
        expect(route2_included['guid']).to eq(route2.guid)
      end

      it 'includes only unique routes when multiple rules reference the same route' do
        # Create another rule on the same route
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'another-rule-on-route1',
          selector: "cf:app:#{valid_uuid}",
          route_id: mtls_route.id
        )

        get '/v3/access_rules?include=route', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Route should appear only once
        route_count = parsed['included']['routes'].count { |r| r['guid'] == mtls_route.guid }
        expect(route_count).to eq(1)
      end

      it 'combines include=route with include=selector_resource' do
        app = VCAP::CloudController::AppModel.make(space: space, name: 'test-app')
        VCAP::CloudController::RouteAccessRule.create(
          guid: SecureRandom.uuid,
          name: 'combined-rule',
          selector: "cf:app:#{app.guid}",
          route_id: mtls_route.id
        )

        get '/v3/access_rules?include=route,selector_resource', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Both routes and selector resources should be included
        expect(parsed['included']['routes']).to be_an(Array)
        expect(parsed['included']['apps']).to be_an(Array)

        # Verify route is present
        route_included = parsed['included']['routes'].find { |r| r['guid'] == mtls_route.guid }
        expect(route_included).to be_present

        # Verify app is present
        app_included = parsed['included']['apps'].find { |a| a['guid'] == app.guid }
        expect(app_included).to be_present
      end
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
