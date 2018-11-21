require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Organizations' do
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user) }
    let!(:organization1) { Organization.make name: 'Apocalypse World' }
    let!(:organization2) { Organization.make name: 'Dungeon World' }
    let!(:organization3) { Organization.make name: 'The Sprawl' }
    let!(:unaccesable_organization) { Organization.make name: 'D&D' }

    before do
      organization1.add_user(user)
      organization2.add_user(user)
      organization3.add_user(user)
    end

    describe 'POST /v3/organizations' do
      it 'creates a new organization with the given name' do
        request_body = {
          name: 'org1',
          metadata: {
            labels: {
              freaky: 'friday'
            }
          }
        }.to_json

        expect {
          post '/v3/organizations', request_body, admin_header
        }.to change {
          Organization.count
        }.by 1

        created_org = Organization.last

        expect(last_response.status).to eq(201)

        expect(parsed_response).to be_a_response_like(
          {
            'guid' => created_org.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'name' => 'org1',
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/organizations/#{created_org.guid}" }
            },
            'metadata' => {
              'labels' => { 'freaky' => 'friday' },
              'annotations' => {}
            }
          }
        )
      end
    end

    describe 'GET /v3/organizations' do
      it 'returns a paginated list of orgs the user has access to' do
        get '/v3/organizations?per_page=2', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/organizations?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/organizations?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/organizations?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => organization1.guid,
                'name' => 'Apocalypse World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}"
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
              },
              {
                'guid' => organization2.guid,
                'name' => 'Dungeon World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
              }
            ]
          }
        )
      end

      context 'label_selector' do
        let!(:orgA) { Organization.make(name: 'A') }
        let!(:orgAFruit) { OrganizationLabelModel.make(key_name: 'fruit', value: 'strawberry', organization: orgA) }
        let!(:orgAAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: orgA) }

        let!(:orgB) { Organization.make(name: 'B') }
        let!(:orgBEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgB) }
        let!(:orgBAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'dog', organization: orgB) }

        let!(:orgC) { Organization.make(name: 'C') }
        let!(:orgCEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgC) }
        let!(:orgCAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: orgC) }

        let!(:orgD) { Organization.make(name: 'D') }
        let!(:orgDEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'prod', organization: orgD) }

        let!(:orgE) { Organization.make(name: 'E') }
        let!(:orgEEnv) { OrganizationLabelModel.make(key_name: 'env', value: 'staging', organization: orgE) }
        let!(:orgEAnimal) { OrganizationLabelModel.make(key_name: 'animal', value: 'dog', organization: orgE) }

        it 'returns the matching orgs' do
          get '/v3/organizations?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_header
          expect(last_response.status).to eq(200), last_response.body

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(orgB.guid, orgC.guid)
        end
      end
    end

    describe 'GET /v3/isolation_segments/:guid/organizations' do
      let(:isolation_segment1) { VCAP::CloudController::IsolationSegmentModel.make(name: 'awesome_seg') }
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

      before do
        assigner.assign(isolation_segment1, [organization2, organization3])
      end

      it 'returns a paginated list of orgs entitled to the isolation segment' do
        get "/v3/isolation_segments/#{isolation_segment1.guid}/organizations?per_page=2", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment1.guid}/organizations?page=1&per_page=2"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => organization2.guid,
                'name' => 'Dungeon World',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization2.guid}"
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
              },
              {
                'guid' => organization3.guid,
                'name' => 'The Sprawl',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/organizations/#{organization3.guid}"
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                }
              }
            ]
          }
        )
      end
    end

    describe 'GET /v3/organizations/:guid/relationships/default_isolation_segment' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
        assigner.assign(isolation_segment, [organization1])
        organization1.update(default_isolation_segment_guid: isolation_segment.guid)
      end

      it 'shows the default isolation segment for the organization' do
        get "/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment", nil, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'data' => {
            'guid' => isolation_segment.guid
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
            'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    describe 'PATCH /v3/organizations/:guid/relationships/default_isolation_segment' do
      let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
      let(:update_request) do
        {
          data: { guid: isolation_segment.guid }
        }.to_json
      end
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
        assigner.assign(isolation_segment, [organization1])
      end

      it 'updates the default isolation segment for the organization' do
        expect(organization1.default_isolation_segment_guid).to be_nil

        patch "/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'data' => {
            'guid' => isolation_segment.guid
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/organizations/#{organization1.guid}/relationships/default_isolation_segment" },
            'related' => { 'href' => "#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}" },
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)

        organization1.reload
        expect(organization1.default_isolation_segment_guid).to eq(isolation_segment.guid)
      end
    end

    describe 'PATCH /v3/organizations/:guid' do
      let(:update_request) do
        {
          name: 'New Name World',
          metadata: {
            labels: {
              freaky: 'thursday'
            },
            annotations: {
              quality: 'p sus'
            }
          },
        }.to_json
      end

      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [organization1])
      end

      it 'updates the name for the organization' do
        patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

        expected_response = {
          'name' => 'New Name World',
          'guid' => organization1.guid,
          'links' => { 'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" } },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'metadata' => {
            'labels' => { 'freaky' => 'thursday' },
            'annotations' => { 'quality' => 'p sus' }
          }
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)

        organization1.reload
        expect(organization1.name).to eq('New Name World')
      end

      context 'deleting labels' do
        let!(:org1Fruit) { OrganizationLabelModel.make(key_name: 'fruit', value: 'strawberry', organization: organization1) }
        let!(:org1Animal) { OrganizationLabelModel.make(key_name: 'animal', value: 'horse', organization: organization1) }
        let(:update_request) do
          {
            metadata: {
              labels: {
                fruit: nil
              }
            },
          }.to_json
        end

        it 'updates the name for the organization' do
          patch "/v3/organizations/#{organization1.guid}", update_request, admin_headers_for(user).merge('CONTENT_TYPE' => 'application/json')

          expected_response = {
            'name' => organization1.name,
            'guid' => organization1.guid,
            'links' => { 'self' => { 'href' => "http://api2.vcap.me/v3/organizations/#{organization1.guid}" } },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => { 'animal' => 'horse' },
              'annotations' => {}
            }
          }

          parsed_response = MultiJson.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end
  end
end
