require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Route Policies' do
  let(:user) { create(:user) }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { create(:organization) }
  let(:space) { create(:space, organization: org) }

  let(:mtls_domain) do
    create(:private_domain,
           owning_organization: org,
           enforce_route_policies: true,
           route_policies_scope: 'space')
  end
  let(:regular_domain) do
    create(:private_domain, owning_organization: org)
  end
  let(:internal_domain) do
    create(:private_domain,
           owning_organization: org,
           internal: true)
  end

  let(:mtls_route) { create(:route, space: space, domain: mtls_domain) }
  let(:regular_route) { create(:route, space: space, domain: regular_domain) }
  let(:internal_route) { create(:route, space: space, domain: internal_domain) }

  let(:valid_uuid) { '11111111-2222-3333-4444-555555555555' }

  let(:route_policy_json) do
    {
      guid: UUID_REGEX,
      created_at: iso8601,
      updated_at: iso8601,
      source: "cf:app:#{valid_uuid}",
      metadata: {
        labels: {},
        annotations: {}
      },
      relationships: {
        route: { data: { guid: mtls_route.guid } },
        app: { data: { guid: valid_uuid } },
        space: { data: nil },
        organization: { data: nil }
      },
      links: {
        self: { href: %r{#{Regexp.escape(link_prefix)}/v3/route_policies/#{UUID_REGEX}} },
        route: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{mtls_route.guid}} },
        app: { href: %r{#{Regexp.escape(link_prefix)}/v3/apps/#{valid_uuid}} }
      }
    }
  end

  describe 'POST /v3/route_policies' do
    let(:request_body) do
      {
        source: "cf:app:#{valid_uuid}",
        relationships: {
          route: { data: { guid: mtls_route.guid } }
        }
      }
    end

    context 'as admin' do
      it 'creates a route policy and returns 201' do
        post '/v3/route_policies', request_body.to_json, admin_header

        expect(last_response.status).to eq(201)
        parsed = Oj.load(last_response.body)
        expect(parsed['source']).to eq("cf:app:#{valid_uuid}")
        expect(parsed['relationships']['route']['data']['guid']).to eq(mtls_route.guid)
      end

      it 'records an audit event' do
        post '/v3/route_policies', request_body.to_json, admin_header

        expect(last_response.status).to eq(201)
        parsed = Oj.load(last_response.body)
        event = VCAP::CloudController::Event.last
        expect(event.type).to eq('audit.route_policy.create')
        expect(event.actee).to eq(parsed['guid'])
        expect(event.actee_type).to eq('route_policy')
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { post '/v3/route_policies', request_body.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        %w[no_role org_billing_manager org_auditor].each { |r| h[r] = { code: 404 } }
        h['admin'] = { code: 201, response_object: route_policy_json }
        h['space_developer'] = { code: 201, response_object: route_policy_json }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the organization is suspended' do
      let(:api_call) { ->(user_headers) { post '/v3/route_policies', request_body.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        %w[no_role org_billing_manager org_auditor].each { |r| h[r] = { code: 404 } }
        h['admin'] = { code: 201, response_object: route_policy_json }
        h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
        h
      end

      before do
        org.update(status: VCAP::CloudController::Organization::SUSPENDED)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/route_policies', request_body.to_json, base_json_headers

        expect(last_response).to have_status_code(401)
      end
    end

    context 'when the domain does not have enforce_route_policies enabled' do
      let(:request_body) do
        {
          source: "cf:app:#{valid_uuid}",
          relationships: {
            route: { data: { guid: regular_route.guid } }
          }
        }
      end

      it 'returns 422' do
        post '/v3/route_policies', request_body.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('enforce_route_policies')
      end
    end

    context 'when the route is on an internal domain' do
      let(:request_body) do
        {
          source: "cf:app:#{valid_uuid}",
          relationships: {
            route: { data: { guid: internal_route.guid } }
          }
        }
      end

      it 'returns 422 with a message about internal domains' do
        post '/v3/route_policies', request_body.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('internal domains')
        expect(last_response.body).to include('container-to-container networking')
      end
    end

    context 'when the route does not exist' do
      let(:request_body) do
        {
          source: "cf:app:#{valid_uuid}",
          relationships: {
            route: { data: { guid: 'nonexistent-guid' } }
          }
        }
      end

      it 'returns 404' do
        post '/v3/route_policies', request_body.to_json, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'cf:any exclusivity' do
      before do
        create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
      end

      it 'rejects cf:any when other policies exist' do
        post '/v3/route_policies', {
          source: 'cf:any',
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('cf:any')
      end
    end

    context 'when a cf:any policy already exists' do
      before do
        create(:route_policy, source: 'cf:any', route_id: mtls_route.id)
      end

      it 'rejects adding a specific selector' do
        post '/v3/route_policies', {
          source: "cf:space:#{valid_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('cf:any')
      end
    end

    context 'duplicate selector per route' do
      before do
        create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
      end

      it 'returns 422' do
        post '/v3/route_policies', {
          source: "cf:app:#{valid_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
      end
    end

    context 'invalid selector format' do
      it 'returns 422' do
        post '/v3/route_policies', {
          source: 'not-valid',
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('Source')
      end
    end

    context 'when a concurrent request creates the same selector (UniqueConstraintViolation)' do
      it 'returns 422 instead of 500' do
        # Simulate a race condition where the DB unique constraint catches the duplicate
        # after validation passes but before the insert commits
        allow_any_instance_of(VCAP::CloudController::RoutePolicy).to receive(:save).and_raise(
          Sequel::UniqueConstraintViolation.new('UNIQUE constraint failed: route_policies.route_id, route_policies.source')
        )

        post '/v3/route_policies', {
          source: "cf:app:#{valid_uuid}",
          relationships: { route: { data: { guid: mtls_route.guid } } }
        }.to_json, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('already exists')
      end
    end
  end

  describe 'GET /v3/route_policies/:guid' do
    let!(:route_policy) do
      create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
    end

    it 'returns the route policy' do
      get "/v3/route_policies/#{route_policy.guid}", nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      expect(parsed['guid']).to eq(route_policy.guid)
      expect(parsed['source']).to eq("cf:app:#{valid_uuid}")
    end

    context 'eager loading' do
      let(:get_route_policy) { -> { get "/v3/route_policies/#{route_policy.guid}", nil, admin_header } }

      it 'eager loads the route and space in the initial fetch' do
        expect { get_route_policy.call }.to have_queried_db_times(/SELECT .* FROM .route_policies. /i, 1)
        expect(last_response.status).to eq(200)

        expect { get_route_policy.call }.to have_queried_db_times(/SELECT .* FROM .routes. /i, 0) # joined via eager_graph, not a separate query
        expect { get_route_policy.call }.to have_queried_db_times(/SELECT .* FROM .spaces. /i, 0) # joined via eager_graph, not a separate query
      end
    end

    context 'role-based visibility' do
      let(:api_call) { ->(headers) { get "/v3/route_policies/#{route_policy.guid}", nil, headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        %w[admin admin_read_only global_auditor
           space_developer space_manager space_auditor space_supporter
           org_manager org_auditor].each { |r| h[r] = { code: 200 } }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the route policy does not exist' do
      it 'returns 404' do
        get '/v3/route_policies/nonexistent-guid', nil, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'with include=source' do
      let!(:frontend_app) { create(:app_model, space: space, name: 'frontend-app') }
      let!(:app_policy) do
        create(:route_policy, source: "cf:app:#{frontend_app.guid}", route_id: mtls_route.id)
      end

      it 'includes the resolved source app resource' do
        get "/v3/route_policies/#{app_policy.guid}?include=source", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        expect(parsed['included']).to be_a(Hash)
        expect(parsed['included']['apps']).to be_an(Array)
        app_included = parsed['included']['apps'].find { |a| a['guid'] == frontend_app.guid }
        expect(app_included).to be_present
        expect(app_included['name']).to eq('frontend-app')
      end
    end

    context 'with include=route' do
      it 'includes the associated route resource' do
        get "/v3/route_policies/#{route_policy.guid}?include=route", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        expect(parsed['included']).to be_a(Hash)
        expect(parsed['included']['routes']).to be_an(Array)
        route_included = parsed['included']['routes'].find { |r| r['guid'] == mtls_route.guid }
        expect(route_included).to be_present
      end
    end

    context 'with include=route,source' do
      let!(:frontend_app) { create(:app_model, space: space, name: 'frontend-app') }
      let!(:app_policy) do
        create(:route_policy, source: "cf:app:#{frontend_app.guid}", route_id: mtls_route.id)
      end

      it 'includes both route and source resources' do
        get "/v3/route_policies/#{app_policy.guid}?include=route,source", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        expect(parsed['included']['routes']).to be_an(Array)
        expect(parsed['included']['apps']).to be_an(Array)
        expect(parsed['included']['routes'].find { |r| r['guid'] == mtls_route.guid }).to be_present
        expect(parsed['included']['apps'].find { |a| a['guid'] == frontend_app.guid }).to be_present
      end
    end

    context 'with an invalid include value' do
      it 'returns 422' do
        get "/v3/route_policies/#{route_policy.guid}?include=invalid_value", nil, admin_header

        expect(last_response.status).to eq(422)
      end
    end
  end

  describe 'GET /v3/route_policies' do
    let!(:policy1) do
      create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
    end
    let!(:policy2) do
      create(:route_policy, source: 'cf:any', route_id: create(:route, space: space, domain: mtls_domain).id)
    end

    it 'lists all accessible route policies' do
      get '/v3/route_policies', nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      guids = parsed['resources'].pluck('guid')
      expect(guids).to include(policy1.guid, policy2.guid)
    end

    context 'role-based visibility' do
      let(:api_call) { ->(headers) { get '/v3/route_policies', nil, headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_guids: [] }.freeze)
        %w[admin admin_read_only global_auditor
           space_developer space_manager space_auditor space_supporter
           org_manager org_auditor].each { |r| h[r] = { code: 200, response_guids: [policy1.guid, policy2.guid] } }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    it 'filters by route_guids' do
      get "/v3/route_policies?route_guids=#{mtls_route.guid}", nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      guids = parsed['resources'].pluck('guid')
      expect(guids).to include(policy1.guid)
      expect(guids).not_to include(policy2.guid)
    end

    it 'filters by selectors' do
      get '/v3/route_policies?sources=cf:any', nil, admin_header

      expect(last_response.status).to eq(200)
      parsed = Oj.load(last_response.body)
      expect(parsed['resources'].length).to eq(1)
      expect(parsed['resources'][0]['source']).to eq('cf:any')
    end

    describe 'with a policy in another space' do
      let(:other_org) { create(:organization) }
      let(:other_space) { create(:space, organization: other_org) }
      let(:other_mtls_domain) do
        create(:private_domain,
               owning_organization: other_org,
               enforce_route_policies: true,
               route_policies_scope: 'space')
      end
      let(:other_route) { create(:route, space: other_space, domain: other_mtls_domain) }
      let!(:policy_in_other_space) do
        create(:route_policy, source: 'cf:any', route_id: other_route.id)
      end

      before do
        other_org.add_user(user)
        other_space.add_developer(user)
      end

      describe 'filtering by space_guids' do
        it 'filters by single space_guid' do
          get "/v3/route_policies?space_guids=#{space.guid}", nil, admin_header

          expect(last_response.status).to eq(200)
          parsed = Oj.load(last_response.body)
          guids = parsed['resources'].pluck('guid')
          expect(guids).to include(policy1.guid, policy2.guid)
          expect(guids).not_to include(policy_in_other_space.guid)
        end

        it 'filters by multiple space_guids' do
          get "/v3/route_policies?space_guids=#{space.guid},#{other_space.guid}", nil, admin_header

          expect(last_response.status).to eq(200)
          parsed = Oj.load(last_response.body)
          guids = parsed['resources'].pluck('guid')
          expect(guids).to include(policy1.guid, policy2.guid, policy_in_other_space.guid)
        end

        it 'combines space_guids with other filters' do
          get "/v3/route_policies?space_guids=#{space.guid}&sources=cf:app:#{valid_uuid}", nil, admin_header

          expect(last_response.status).to eq(200)
          parsed = Oj.load(last_response.body)
          expect(parsed['resources'].length).to eq(1)
          expect(parsed['resources'][0]['guid']).to eq(policy1.guid)
          expect(parsed['resources'][0]['source']).to eq("cf:app:#{valid_uuid}")
        end

        it 'returns empty when space has no route policies' do
          empty_space = create(:space, organization: org)
          org.add_user(user)
          empty_space.add_developer(user)

          get "/v3/route_policies?space_guids=#{empty_space.guid}", nil, admin_header

          expect(last_response.status).to eq(200)
          parsed = Oj.load(last_response.body)
          expect(parsed['resources'].length).to eq(0)
        end
      end

      describe 'filtering by both route_guids and space_guids' do
        it 'returns results matching both route_guids and space_guids without ambiguous column errors' do
          get "/v3/route_policies?route_guids=#{mtls_route.guid}&space_guids=#{space.guid}", nil, admin_header

          expect(last_response.status).to eq(200)
          parsed = Oj.load(last_response.body)
          guids = parsed['resources'].pluck('guid')
          expect(guids).to include(policy1.guid)
          expect(guids).not_to include(policy_in_other_space.guid)
        end
      end
    end

    describe 'filtering by source_guids' do
      let(:app1) { create(:app_model, space: space) }
      let(:app2) { create(:app_model, space: space) }
      let!(:app1_policy) do
        create(:route_policy, source: "cf:app:#{app1.guid}", route_id: mtls_route.id)
      end
      let!(:app2_policy) do
        create(:route_policy, source: "cf:app:#{app2.guid}", route_id: mtls_route.id)
      end

      it 'returns only the policy whose source_guid matches the queried GUID' do
        get "/v3/route_policies?source_guids=#{app1.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        returned_guids = parsed['resources'].pluck('guid')
        expect(returned_guids).to include(app1_policy.guid)
        expect(returned_guids).not_to include(app2_policy.guid)
      end

      it 'returns an empty list when the GUID matches nothing' do
        get "/v3/route_policies?source_guids=#{SecureRandom.uuid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        expect(parsed['resources']).to be_empty
      end

      it 'does not return cf:any policies for a GUID query' do
        any_route = create(:route, space: space, domain: mtls_domain)
        create(:route_policy, source: 'cf:any', route_id: any_route.id)

        get "/v3/route_policies?source_guids=#{app1.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        returned_sources = parsed['resources'].pluck('source')
        expect(returned_sources).not_to include('cf:any')
      end
    end

    describe 'filtering by sources' do
      let(:app1) { create(:app_model, space: space) }
      let(:route2) { create(:route, space: space, domain: mtls_domain) }
      let!(:typed_policy) do
        create(:route_policy, source: "cf:app:#{app1.guid}", route_id: mtls_route.id)
      end
      let!(:any_policy) do
        create(:route_policy, source: 'cf:any', route_id: route2.id)
      end

      it 'returns only the policy with the exact source value' do
        get "/v3/route_policies?sources=cf:app:#{app1.guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        guids = parsed['resources'].pluck('guid')
        expect(guids).to include(typed_policy.guid)
        expect(guids).not_to include(any_policy.guid)
      end

      it 'returns cf:any policies when sources=cf:any' do
        get '/v3/route_policies?sources=cf:any', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        guids = parsed['resources'].pluck('guid')
        expect(guids).to include(any_policy.guid)
        expect(guids).not_to include(typed_policy.guid)
      end
    end

    describe 'filtering by label_selector' do
      let(:route1) { create(:route, space: space, domain: mtls_domain) }
      let(:route2) { create(:route, space: space, domain: mtls_domain) }
      let!(:labelled_policy) do
        policy = create(:route_policy, source: 'cf:any', route_id: route1.id)
        create(:route_policy_label_model, resource_guid: policy.guid, key_name: 'env', value: 'prod')
        policy
      end
      let!(:unlabelled_policy) do
        create(:route_policy, source: 'cf:any', route_id: route2.id)
      end

      it 'returns only policies matching the label selector' do
        get '/v3/route_policies?label_selector=env=prod', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)
        guids = parsed['resources'].pluck('guid')
        expect(guids).to include(labelled_policy.guid)
        expect(guids).not_to include(unlabelled_policy.guid)
      end
    end

    context 'with include=source' do
      let!(:frontend_app) { create(:app_model, space: space, name: 'frontend-app') }
      let!(:other_space) { create(:space, organization: org, name: 'other-space') }
      let!(:other_org) { create(:organization, name: 'other-org') }

      let!(:app_policy) do
        create(:route_policy, source: "cf:app:#{frontend_app.guid}", route_id: mtls_route.id)
      end

      let!(:space_policy) do
        create(:route_policy, source: "cf:space:#{other_space.guid}", route_id: mtls_route.id)
      end

      let!(:org_policy) do
        create(:route_policy, source: "cf:org:#{other_org.guid}", route_id: mtls_route.id)
      end

      it 'includes resolved selector resources' do
        get '/v3/route_policies?include=source', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Check included structure
        expect(parsed['included']).to be_a(Hash)
        expect(parsed['included']['apps']).to be_an(Array)
        expect(parsed['included']['spaces']).to be_an(Array)
        expect(parsed['included']['organizations']).to be_an(Array)

        # Check app is included with full details
        app_included = parsed['included']['apps'].find { |a| a['guid'] == frontend_app.guid }
        expect(app_included).to be_present
        expect(app_included['name']).to eq('frontend-app')
        expect(app_included['guid']).to eq(frontend_app.guid)

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
        create(:route_policy, source: "cf:app:#{stale_guid}", route_id: mtls_route.id)

        get '/v3/route_policies?include=source', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Stale resource should not appear in included
        stale_app = parsed['included']['apps'].find { |a| a['guid'] == stale_guid }
        expect(stale_app).to be_nil
      end

      it 'includes only unique resources when multiple policies reference the same resource' do
        # Create another policy referencing the same app
        create(:route_policy, source: "cf:app:#{frontend_app.guid}", route_id: create(:route, space: space, domain: mtls_domain).id)

        get '/v3/route_policies?include=source', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # App should appear only once
        app_count = parsed['included']['apps'].count { |a| a['guid'] == frontend_app.guid }
        expect(app_count).to eq(1)
      end

      it 'does not include resources for cf:any selectors' do
        create(:route_policy, source: 'cf:any', route_id: create(:route, space: space, domain: mtls_domain).id)

        get '/v3/route_policies?include=source', nil, admin_header

        expect(last_response.status).to eq(200)
        # Should succeed without error even with cf:any selector
      end
    end

    context 'with include=route' do
      let(:route2) { create(:route, space: space, domain: mtls_domain) }

      let!(:policy_on_route1) do
        create(:route_policy, source: "cf:app:#{SecureRandom.uuid}", route_id: mtls_route.id)
      end

      let!(:policy_on_route2) do
        create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: route2.id)
      end

      it 'includes route resources' do
        get '/v3/route_policies?include=route', nil, admin_header

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

      it 'includes only unique routes when multiple policies reference the same route' do
        # Create another policy on the same route with a different selector
        create(:route_policy, source: "cf:app:#{SecureRandom.uuid}", route_id: mtls_route.id)

        get '/v3/route_policies?include=route', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Route should appear only once
        route_count = parsed['included']['routes'].count { |r| r['guid'] == mtls_route.guid }
        expect(route_count).to eq(1)
      end

      it 'combines include=route with include=source' do
        test_app = create(:app_model, space: space, name: 'test-app')
        create(:route_policy, source: "cf:app:#{test_app.guid}", route_id: mtls_route.id)

        get '/v3/route_policies?include=route,source', nil, admin_header

        expect(last_response.status).to eq(200)
        parsed = Oj.load(last_response.body)

        # Both routes and selector resources should be included
        expect(parsed['included']['routes']).to be_an(Array)
        expect(parsed['included']['apps']).to be_an(Array)

        # Verify route is present
        route_included = parsed['included']['routes'].find { |r| r['guid'] == mtls_route.guid }
        expect(route_included).to be_present

        # Verify app is present
        app_included = parsed['included']['apps'].find { |a| a['guid'] == test_app.guid }
        expect(app_included).to be_present
      end
    end
  end

  describe 'DELETE /v3/route_policies/:guid' do
    let!(:route_policy) do
      create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
    end

    it 'deletes the route policy and returns 204' do
      delete "/v3/route_policies/#{route_policy.guid}", nil, admin_header

      expect(last_response.status).to eq(204)
      expect(VCAP::CloudController::RoutePolicy.find(guid: route_policy.guid)).to be_nil
    end

    it 'records an audit event' do
      policy_guid = route_policy.guid
      delete "/v3/route_policies/#{policy_guid}", nil, admin_header

      expect(last_response.status).to eq(204)
      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.route_policy.delete')
      expect(event.actee).to eq(policy_guid)
      expect(event.actee_type).to eq('route_policy')
    end

    context 'when destroy fails' do
      it 'does not record an audit event' do
        allow_any_instance_of(VCAP::CloudController::RoutePolicy).to receive(:destroy).and_raise(Sequel::Error.new('db error'))
        allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)

        expect do
          delete "/v3/route_policies/#{route_policy.guid}", nil, admin_header
        end.not_to change(VCAP::CloudController::Event, :count)

        expect(last_response.status).to eq(500)
      end
    end

    context 'when the route policy does not exist' do
      it 'returns 404' do
        delete '/v3/route_policies/nonexistent-guid', nil, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { delete "/v3/route_policies/#{route_policy.guid}", nil, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        %w[no_role org_billing_manager].each { |r| h[r] = { code: 404 } }
        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/route_policies/#{route_policy.guid}", nil, base_json_headers

        expect(last_response).to have_status_code(401)
      end
    end
  end

  describe 'PATCH /v3/route_policies/:guid (metadata update)' do
    let!(:route_policy) do
      create(:route_policy, source: "cf:app:#{valid_uuid}", route_id: mtls_route.id)
    end
    let(:update_request_body) do
      { metadata: { labels: { env: 'production' } } }
    end
    let(:updated_route_policy_json) do
      route_policy_json.merge(
        guid: route_policy.guid,
        metadata: { labels: { env: 'production' }, annotations: {} }
      )
    end

    it 'returns 200 and the updated route policy' do
      patch "/v3/route_policies/#{route_policy.guid}", update_request_body.to_json, admin_header

      expect(last_response.status).to eq(200)
      expect(parsed_response).to match_json_response(updated_route_policy_json)
    end

    it 'records an audit event' do
      patch "/v3/route_policies/#{route_policy.guid}", update_request_body.to_json, admin_header

      expect(last_response.status).to eq(200)
      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.route_policy.update')
      expect(event.actee).to eq(route_policy.guid)
      expect(event.actee_type).to eq('route_policy')
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { patch "/v3/route_policies/#{route_policy.guid}", update_request_body.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        %w[no_role org_billing_manager].each { |r| h[r] = { code: 404 } }
        h['admin'] = { code: 200, response_object: updated_route_policy_json }
        h['space_developer'] = { code: 200, response_object: updated_route_policy_json }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the route policy does not exist' do
      it 'returns 404' do
        patch '/v3/route_policies/nonexistent-guid', {}.to_json, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        patch "/v3/route_policies/#{route_policy.guid}", update_request_body.to_json, base_json_headers

        expect(last_response).to have_status_code(401)
      end
    end
  end
end
