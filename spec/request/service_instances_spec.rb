require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:another_space) { VCAP::CloudController::Space.make }

  describe 'GET /v3/service_instances' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_instances', nil, user_headers } }

    let!(:msi_1) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let!(:msi_2) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }
    let!(:upsi_1) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
    let!(:upsi_2) { VCAP::CloudController::UserProvidedServiceInstance.make(space: another_space) }
    let!(:ssi) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }

    before do
      ssi.add_shared_space(space)
    end

    describe 'list query parameters' do
      let(:user_header) { admin_headers }
      let(:request) { 'v3/service_instances' }
      let(:message) { VCAP::CloudController::ServiceInstancesListMessage }

      let(:params) do
        {
          names: ['foo', 'bar'],
          space_guids: ['foo', 'bar'],
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo,bar',
        }
      end

      it_behaves_like 'request_spec_shared_examples.rb list query endpoint'
    end

    describe 'permissions' do
      let(:all_instances) do
        {
          code: 200,
          response_objects: [
            create_managed_json(msi_1),
            create_managed_json(msi_2),
            create_user_provided_json(upsi_1),
            create_user_provided_json(upsi_2),
            create_managed_json(ssi),
          ]
        }
      end

      let(:space_instances) do
        {
          code: 200,
          response_objects: [
            create_managed_json(msi_1),
            create_user_provided_json(upsi_1),
            create_managed_json(ssi),
          ]
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: []
        )

        h['admin'] = all_instances
        h['admin_read_only'] = all_instances
        h['global_auditor'] = all_instances
        h['space_developer'] = space_instances
        h['space_manager'] = space_instances
        h['space_auditor'] = space_instances
        h['org_manager'] = space_instances

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'pagination' do
      let(:resources) { [msi_1, msi_2, upsi_1, upsi_2, ssi] }
      it_behaves_like 'paginated response', '/v3/service_instances'
    end

    describe 'filters' do
      it 'filters by name' do
        get "/v3/service_instances?names=#{msi_1.name}", nil, admin_headers
        check_filtered_instances(create_managed_json(msi_1))
      end

      it 'filters by space guid' do
        get "/v3/service_instances?space_guids=#{another_space.guid}", nil, admin_headers
        check_filtered_instances(
          create_managed_json(msi_2),
          create_user_provided_json(upsi_2),
          create_managed_json(ssi),
        )
      end

      it 'filters by label' do
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: msi_1)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'raspberry', service_instance: msi_2)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: ssi)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'strawberry', service_instance: upsi_2)

        get '/v3/service_instances?label_selector=fruit=strawberry', nil, admin_headers

        check_filtered_instances(
          create_managed_json(msi_1, labels: { fruit: 'strawberry' }),
          create_user_provided_json(upsi_2, labels: { fruit: 'strawberry' }),
          create_managed_json(ssi, labels: { fruit: 'strawberry' }),
        )
      end
    end

    def check_filtered_instances(*instances)
      expect(last_response).to have_status_code(200)
      expect(parsed_response['resources'].length).to be(instances.length)
      expect({ resources: parsed_response['resources'] }).to match_json_response(
        { resources: instances }
      )
    end

    def create_managed_json(instance, labels: {})
      {
        guid: instance.guid,
        name: instance.name,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'managed',
        dashboard_url: nil,
        last_operation: {},
        maintenance_info: {},
        upgrade_available: false,
        tags: [],
        metadata: {
          labels: labels,
          annotations: {},
        },
        relationships: {
          space: {
            data: {
              guid: instance.space.guid
            }
          }
        },
        links: {
          self: {
            href: %r(#{Regexp.escape(link_prefix)}/v3/service_instances/#{instance.guid})
          },
          space: {
            href: %r(#{Regexp.escape(link_prefix)}/v3/spaces/#{instance.space.guid})
          },
        },
      }
    end

    def create_user_provided_json(instance, labels: {})
      {
        guid: instance.guid,
        name: instance.name,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'user-provided',
        syslog_drain_url: instance.syslog_drain_url,
        route_service_url: nil,
        tags: [],
        metadata: {
          labels: labels,
          annotations: {},
        },
        relationships: {
          space: {
            data: {
              guid: instance.space.guid
            }
          }
        },
        links: {
          self: {
            href: %r(#{Regexp.escape(link_prefix)}/v3/service_instances/#{instance.guid})
          },
          space: {
            href: %r(#{Regexp.escape(link_prefix)}/v3/spaces/#{instance.space.guid})
          },
        },
      }
    end
  end

  describe 'unrefactored' do
    let(:user_email) { 'user@email.example.com' }
    let(:user_name) { 'username' }
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { headers_for(user) }
    let(:admin_header) { admin_headers_for(user, email: user_email, user_name: user_name) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:another_space) { VCAP::CloudController::Space.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: false, error_message: nil) }
    let!(:annotations) { VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value') }
    let!(:service_instance1) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'rabbitmq') }
    let!(:service_instance2) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'redis') }
    let!(:service_instance3) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, name: 'mysql') }

    describe 'GET /v3/service_instances/:guid/relationships/shared_spaces' do
      before do
        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        enable_feature_flag!
        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
        expect(last_response.status).to eq(200)

        disable_feature_flag!
      end

      it 'returns a list of space guids where the service instance is shared to' do
        set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)

        get "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", nil, user_header

        expect(last_response.status).to eq(200)

        expected_response = {
          'data' => [
            { 'guid' => target_space.guid }
          ],
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
      end

      it 'shares the service instance with the target space' do
        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expected_response = {
          'data' => [
            { 'guid' => target_space.guid }
          ],
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
          }
        }

        expect(parsed_response).to be_a_response_like(expected_response)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type: 'audit.service_instance.share',
          actor: user.guid,
          actor_type: 'user',
          actor_name: user_email,
          actor_username: user_name,
          actee: service_instance1.guid,
          actee_type: 'service_instance',
          actee_name: service_instance1.name,
          space_guid: space.guid,
          organization_guid: space.organization.guid
        })
        expect(event.metadata['target_space_guids']).to eq([target_space.guid])
      end
    end

    describe 'PATCH /v3/service_instances/:guid' do
      before do
        service_instance1.annotation_ids = [annotations.id]
      end
      let(:metadata_request) do
        {
          "metadata": {
            "labels": {
              "potato": 'yam',
              "style": 'baked'
            },
            "annotations": {
              "potato": 'idaho',
              "style": 'mashed',
              "pre.fix/to_delete": nil
            }
          }
        }
      end

      it 'updates metadata on a service instance' do
        patch "/v3/service_instances/#{service_instance1.guid}", metadata_request.to_json, admin_header

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)

        expect(parsed_response).to be_a_response_like(
          {
            'guid' => service_instance1.guid,
            'name' => service_instance1.name,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'dashboard_url' => nil,
            'last_operation' => {},
            'maintenance_info' => {},
            'tags' => [],
            'type' => 'managed',
            'upgrade_available' => false,
            'relationships' => {
              'space' => {
                'data' => {
                  'guid' => service_instance1.space.guid
                }
              }
            },
            'links' => {
              'space' => {
                'href' => "#{link_prefix}/v3/spaces/#{service_instance1.space.guid}"
              },
              'self' => {
                'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}"
              }
            },
            'metadata' => {
              'labels' => {
                'potato' => 'yam',
                'style' => 'baked'
              },
              'annotations' => {
                'potato' => 'idaho',
                'style' => 'mashed'
              }
            }
          }
        )
      end
    end

    describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space-guid' do
      before do
        allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
          FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        end

        share_request = {
          'data' => [
            { 'guid' => target_space.guid }
          ]
        }

        enable_feature_flag!
        post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
        expect(last_response.status).to eq(200)

        disable_feature_flag!
      end

      it 'unshares the service instance from the target space' do
        delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
        expect(last_response.status).to eq(204)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type: 'audit.service_instance.unshare',
          actor: user.guid,
          actor_type: 'user',
          actor_name: user_email,
          actor_username: user_name,
          actee: service_instance1.guid,
          actee_type: 'service_instance',
          actee_name: service_instance1.name,
          space_guid: space.guid,
          organization_guid: space.organization.guid
        })
        expect(event.metadata['target_space_guid']).to eq(target_space.guid)
      end

      it 'deletes associated bindings in target space when service instance is unshared' do
        process = VCAP::CloudController::ProcessModelFactory.make(diego: false, space: target_space)

        enable_feature_flag!
        service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: service_instance1, app: process.app, credentials: { secret: 'key' })
        disable_feature_flag!

        get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
        expect(last_response.status).to eq(200)

        delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
        expect(last_response.status).to eq(204)

        get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
        expect(last_response.status).to eq(404)
      end
    end

    def enable_feature_flag!
      feature_flag.enabled = true
      feature_flag.save
    end

    def disable_feature_flag!
      feature_flag.enabled = false
      feature_flag.save
    end
  end
end
