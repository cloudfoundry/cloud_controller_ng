require 'spec_helper'

RSpec.describe 'Spaces' do
  let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }

  describe 'POST /v2/spaces' do
    let(:opts) do
      MultiJson.dump({
        'name' => 'space_name',
        'organization_guid' => org.guid,
        'isolation_segment_guid' => isolation_segment.guid
      })
    end

    context 'as admin' do
      it 'creates a space and associates the isolation segment' do
        post '/v2/spaces', opts, admin_headers_for(user)

        expect(last_response.status).to eq(201)
        parsed_response = MultiJson.load(last_response.body)

        space = VCAP::CloudController::Space.last

        expect(parsed_response).to be_a_response_like({
          'metadata' => {
            'guid' => space.guid,
            'url' => "/v2/spaces/#{space.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'name' => space.name,
            'organization_guid' => org.guid,
            'space_quota_definition_guid' => nil,
            'isolation_segment_guid' => isolation_segment.guid,
            'allow_ssh' => true,
            'organization_url' => "/v2/organizations/#{org.guid}",
            'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
            'developers_url' => "/v2/spaces/#{space.guid}/developers",
            'managers_url' => "/v2/spaces/#{space.guid}/managers",
            'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
            'apps_url' => "/v2/spaces/#{space.guid}/apps",
            'routes_url' => "/v2/spaces/#{space.guid}/routes",
            'domains_url' => "/v2/spaces/#{space.guid}/domains",
            'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
            'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
            'events_url' => "/v2/spaces/#{space.guid}/events",
            'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups"
          }
        })
      end
    end
  end

  describe 'GET /v2/spaces' do
    context 'when a isolation segment is associated to the space' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      before do
        isolation_segment.add_space(space)

        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'lists the isolation segment for SpaceDvelopers' do
        get '/v2/spaces', {}, headers_for(user)

        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)

        expect(parsed_response).to be_a_response_like({
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [{
            'metadata' => {
              'guid' => space.guid,
              'url' => "/v2/spaces/#{space.guid}",
              'created_at' => iso8601,
              'updated_at' => iso8601,
            },
            'entity' => {
              'name' => space.name,
              'organization_guid' => org.guid,
              'space_quota_definition_guid' => nil,
              'isolation_segment_guid' => isolation_segment.guid,
              'allow_ssh' => true,
              'organization_url' => "/v2/organizations/#{org.guid}",
              'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
              'developers_url' => "/v2/spaces/#{space.guid}/developers",
              'managers_url' => "/v2/spaces/#{space.guid}/managers",
              'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
              'apps_url' => "/v2/spaces/#{space.guid}/apps",
              'routes_url' => "/v2/spaces/#{space.guid}/routes",
              'domains_url' => "/v2/spaces/#{space.guid}/domains",
              'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
              'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
              'events_url' => "/v2/spaces/#{space.guid}/events",
              'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups"
            }
          }]
        })
      end
    end
  end

  describe 'GET /v2/spaces/:guid' do
    context 'when a isolation segment is associated to the space' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      before do
        isolation_segment.add_space(space)

        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'lists the isolation segment for SpaceDvelopers' do
        get "/v2/spaces/#{space.guid}", {}, headers_for(user)

        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)

        expect(parsed_response).to be_a_response_like({
          'metadata' => {
            'guid' => space.guid,
            'url' => "/v2/spaces/#{space.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601,
          },
          'entity' => {
            'name' => space.name,
            'organization_guid' => org.guid,
            'space_quota_definition_guid' => nil,
            'isolation_segment_guid' => isolation_segment.guid,
            'allow_ssh' => true,
            'organization_url' => "/v2/organizations/#{org.guid}",
            'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment.guid}",
            'developers_url' => "/v2/spaces/#{space.guid}/developers",
            'managers_url' => "/v2/spaces/#{space.guid}/managers",
            'auditors_url' => "/v2/spaces/#{space.guid}/auditors",
            'apps_url' => "/v2/spaces/#{space.guid}/apps",
            'routes_url' => "/v2/spaces/#{space.guid}/routes",
            'domains_url' => "/v2/spaces/#{space.guid}/domains",
            'service_instances_url' => "/v2/spaces/#{space.guid}/service_instances",
            'app_events_url' => "/v2/spaces/#{space.guid}/app_events",
            'events_url' => "/v2/spaces/#{space.guid}/events",
            'security_groups_url' => "/v2/spaces/#{space.guid}/security_groups"
          }
        })
      end
    end
  end
end
