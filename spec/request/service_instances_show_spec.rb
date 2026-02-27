require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances - Show and List' do
  include_context 'service instances setup'

  describe 'GET /v3/service_instances/:guid' do
    let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{guid}", nil, user_headers } }

    context 'no such instance' do
      let(:guid) { 'no-such-guid' }

      let(:expected_codes_and_responses) do
        Hash.new({ code: 404 }.freeze)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'managed service instance' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(create_managed_json(instance))
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'user-provided service instance' do
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(create_user_provided_json(instance))
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'shared service instance' do
      let(:another_space) { VCAP::CloudController::Space.make }
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }
      let(:guid) { instance.guid }

      before do
        instance.add_shared_space(space)
      end

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(create_managed_json(instance))
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'fields' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
      let(:guid) { instance.guid }

      it 'can include the organization name and guid fields' do
        get "/v3/service_instances/#{guid}?fields[space.organization]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          organizations: [
            {
              name: space.organization.name,
              guid: space.organization.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end

      it 'can include the space name and guid fields' do
        get "/v3/service_instances/#{guid}?fields[space]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          spaces: [
            {
              name: space.name,
              guid: space.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end

      it 'can include service plan guid and name fields' do
        get "/v3/service_instances/#{guid}?fields[service_plan]=guid,name", nil, admin_headers

        expect(last_response).to have_status_code(200)

        included = {
          service_plans: [
            {
              guid: instance.service_plan.guid,
              name: instance.service_plan.name
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end

      it 'can include service offering and broker fields' do
        get "/v3/service_instances/#{guid}?fields[service_plan.service_offering]=name,guid,description,documentation_url&" \
            'fields[service_plan.service_offering.service_broker]=name,guid', nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          service_offerings: [
            {
              name: instance.service_plan.service.name,
              guid: instance.service_plan.service.guid,
              description: instance.service_plan.service.description,
              documentation_url: 'https://some.url.for.docs/'
            }
          ],
          service_brokers: [
            {
              name: instance.service_plan.service.service_broker.name,
              guid: instance.service_plan.service.service_broker.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end
    end
  end

  describe 'GET /v3/service_instances' do
    let(:api_call) { ->(user_headers) { get '/v3/service_instances', nil, user_headers } }

    it_behaves_like 'list query endpoint' do
      let(:user_header) { admin_headers }
      let(:request) { 'v3/service_instances' }
      let(:message) { VCAP::CloudController::ServiceInstancesListMessage }

      let(:params) do
        {
          names: %w[foo bar],
          space_guids: %w[foo bar],
          organization_guids: %w[org-1 org-2],
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          type: 'managed',
          service_plan_guids: %w[guid-1 guid-2],
          service_plan_names: %w[plan-1 plan-2],
          fields: { 'space.organization' => 'name' },
          guids: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end
    end

    describe 'pagination' do
      let!(:resources) { Array.new(2) { VCAP::CloudController::ServiceInstance.make } }

      it_behaves_like 'paginated response', '/v3/service_instances'

      it_behaves_like 'paginated fields response', '/v3/service_instances', 'space', 'guid,name,relationships.organization'

      it_behaves_like 'paginated fields response', '/v3/service_instances', 'space.organization', 'name,guid'
    end

    describe 'order_by' do
      it_behaves_like 'list endpoint order_by name', '/v3/service_instances' do
        let(:resource_klass) { VCAP::CloudController::ServiceInstance }
      end

      it_behaves_like 'list endpoint order_by timestamps', '/v3/service_instances' do
        let(:resource_klass) { VCAP::CloudController::ServiceInstance }
      end
    end

    context 'given a mixture of managed, user-provided and shared service instances' do
      let!(:msi_1) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: VCAP::CloudController::ServicePlan.make(
            service: VCAP::CloudController::Service.make(
              service_broker: VCAP::CloudController::ServiceBroker.make(created_at: Time.now.utc - 2.seconds),
              created_at: Time.now.utc - 2.seconds
            ),
            created_at: Time.now.utc - 2.seconds
          ),
          space: space
        )
      end
      let!(:msi_2) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: VCAP::CloudController::ServicePlan.make(
            service: VCAP::CloudController::Service.make(
              service_broker: VCAP::CloudController::ServiceBroker.make(created_at: Time.now.utc - 1.second),
              created_at: Time.now.utc - 1.second
            ),
            created_at: Time.now.utc - 1.second
          ),
          space: another_space
        )
      end
      let!(:upsi_1) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }
      let!(:upsi_2) { VCAP::CloudController::UserProvidedServiceInstance.make(space: another_space) }
      let!(:ssi) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }

      before do
        ssi.add_shared_space(space)
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
              create_managed_json(ssi)
            ]
          }
        end

        let(:space_instances) do
          {
            code: 200,
            response_objects: [
              create_managed_json(msi_1),
              create_user_provided_json(upsi_1),
              create_managed_json(ssi)
            ]
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            { code: 200,
              response_objects: [] }.freeze
          )

          h['admin'] = all_instances
          h['admin_read_only'] = all_instances
          h['global_auditor'] = all_instances
          h['space_supporter'] = space_instances
          h['space_developer'] = space_instances
          h['space_manager'] = space_instances
          h['space_auditor'] = space_instances
          h['org_manager'] = space_instances

          h
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
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
            create_managed_json(ssi)
          )
        end

        it 'filters by organization guids' do
          get "/v3/service_instances?organization_guids=#{another_space.organization.guid}", nil, admin_headers
          check_filtered_instances(
            create_managed_json(msi_2),
            create_user_provided_json(upsi_2),
            create_managed_json(ssi)
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
            create_managed_json(ssi, labels: { fruit: 'strawberry' })
          )
        end

        it 'filters by type' do
          get '/v3/service_instances?type=managed', nil, admin_headers
          check_filtered_instances(
            create_managed_json(msi_1),
            create_managed_json(msi_2),
            create_managed_json(ssi)
          )
        end

        it 'filters by service_plan_guids' do
          get "/v3/service_instances?service_plan_guids=#{msi_1.service_plan.guid},#{msi_2.service_plan.guid}", nil, admin_headers
          check_filtered_instances(
            create_managed_json(msi_1),
            create_managed_json(msi_2)
          )
        end

        it 'filters by service_plan_names' do
          get "/v3/service_instances?service_plan_names=#{msi_1.service_plan.name},#{msi_2.service_plan.name}", nil, admin_headers
          check_filtered_instances(
            create_managed_json(msi_1),
            create_managed_json(msi_2)
          )
        end

        def check_filtered_instances(*instances)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].length).to be(instances.length)
          expect({ resources: parsed_response['resources'] }).to match_json_response(
            { resources: instances }
          )
        end
      end

      context 'fields' do
        it 'can include the space and organization name and guid fields' do
          get '/v3/service_instances?fields[space]=guid,name,relationships.organization&fields[space.organization]=name,guid', nil, admin_headers
          expect(last_response).to have_status_code(200)

          included = {
            spaces: [
              {
                guid: space.guid,
                name: space.name,
                relationships: {
                  organization: {
                    data: {
                      guid: space.organization.guid
                    }
                  }
                }
              },
              {
                guid: another_space.guid,
                name: another_space.name,
                relationships: {
                  organization: {
                    data: {
                      guid: another_space.organization.guid
                    }
                  }
                }
              }
            ],
            organizations: [
              {
                name: space.organization.name,
                guid: space.organization.guid
              },
              {
                name: another_space.organization.name,
                guid: another_space.organization.guid
              }
            ]
          }

          expect({ included: parsed_response['included'] }).to match_json_response({ included: })
        end

        it 'can include the service plan, offering and broker fields' do
          get '/v3/service_instances?fields[service_plan]=guid,name,relationships.service_offering&' \
              'fields[service_plan.service_offering]=name,guid,description,documentation_url,relationships.service_broker&' \
              'fields[service_plan.service_offering.service_broker]=name,guid', nil, admin_headers

          expect(last_response).to have_status_code(200)

          included = {
            service_plans: [
              {
                guid: msi_1.service_plan.guid,
                name: msi_1.service_plan.name,
                relationships: {
                  service_offering: {
                    data: {
                      guid: msi_1.service_plan.service.guid
                    }
                  }
                }
              },
              {
                guid: msi_2.service_plan.guid,
                name: msi_2.service_plan.name,
                relationships: {
                  service_offering: {
                    data: {
                      guid: msi_2.service_plan.service.guid
                    }
                  }
                }
              },
              {
                guid: ssi.service_plan.guid,
                name: ssi.service_plan.name,
                relationships: {
                  service_offering: {
                    data: {
                      guid: ssi.service_plan.service.guid
                    }
                  }
                }
              }
            ],
            service_offerings: [
              {
                name: msi_1.service_plan.service.name,
                guid: msi_1.service_plan.service.guid,
                description: msi_1.service_plan.service.description,
                documentation_url: 'https://some.url.for.docs/',
                relationships: {
                  service_broker: {
                    data: {
                      guid: msi_1.service_plan.service.service_broker.guid
                    }
                  }
                }
              },
              {
                name: msi_2.service_plan.service.name,
                guid: msi_2.service_plan.service.guid,
                description: msi_2.service_plan.service.description,
                documentation_url: 'https://some.url.for.docs/',
                relationships: {
                  service_broker: {
                    data: {
                      guid: msi_2.service_plan.service.service_broker.guid
                    }
                  }
                }
              },
              {
                name: ssi.service_plan.service.name,
                guid: ssi.service_plan.service.guid,
                description: ssi.service_plan.service.description,
                documentation_url: 'https://some.url.for.docs/',
                relationships: {
                  service_broker: {
                    data: {
                      guid: ssi.service_plan.service.service_broker.guid
                    }
                  }
                }
              }
            ],
            service_brokers: [
              {
                name: msi_1.service_plan.service.service_broker.name,
                guid: msi_1.service_plan.service.service_broker.guid
              },
              {
                name: msi_2.service_plan.service.service_broker.name,
                guid: msi_2.service_plan.service.service_broker.guid
              },
              {
                name: ssi.service_plan.service.service_broker.name,
                guid: ssi.service_plan.service.service_broker.guid
              }

            ]
          }

          expect({ included: parsed_response['included'] }).to match_json_response({ included: })
        end
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::ServiceInstanceListFetcher).to receive(:fetch).with(
          an_instance_of(VCAP::CloudController::ServiceInstancesListMessage),
          hash_including(eager_loaded_associations: %i[labels annotations space service_instance_operation service_plan_sti_eager_load])
        ).and_call_original

        get '/v3/service_instances', nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::ServiceInstance }
      let(:api_call) do
        ->(headers, filters) { get "/v3/service_instances?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'GET /v3/service_instances/:guid/credentials' do
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{guid}/credentials", nil, user_headers } }
      let(:credentials) { { 'fake-key' => 'fake-value' } }
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:, credentials:) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 200,
            response_object: credentials }.freeze
        )

        h['global_auditor'] = h['space_supporter'] = h['space_manager'] = h['space_auditor'] = h['org_manager'] = { code: 403 }
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
        h
      end
    end

    it 'responds with an empty obect when no credentials were set' do
      upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, credentials: nil)
      get "/v3/service_instances/#{upsi.guid}/credentials", nil, admin_headers
      expect(last_response).to have_status_code(200)
      expect(parsed_response).to match_json_response({})
    end

    it 'responds with 404 when the instance does not exist' do
      get '/v3/service_instances/does-not-exist/credentials', nil, admin_headers
      expect(last_response).to have_status_code(404)
    end

    it 'responds with 404 for a managed service instance' do
      msi = VCAP::CloudController::ManagedServiceInstance.make(space:)
      get "/v3/service_instances/#{msi.guid}/credentials", nil, admin_headers
      expect(last_response).to have_status_code(404)
    end

    it 'records an audit event' do
      upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, credentials: {})
      get "/v3/service_instances/#{upsi.guid}/credentials", nil, space_dev_headers
      expect(last_response).to have_status_code(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.user_provided_service_instance.show',
                                        actor: user.guid,
                                        actee: upsi.guid,
                                        actee_type: 'user_provided_service_instance',
                                        actee_name: upsi.name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
    end
  end

  describe 'GET /v3/service_instances/:guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service:) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:, service_plan:) }
    let(:body) { {}.to_json }
    let(:response_code) { 200 }

    before do
      stub_request(:get, %r{#{instance.service.service_broker.broker_url}/v2/service_instances/#{guid_pattern}}).
        with(basic_auth: basic_auth(service_broker: instance.service.service_broker)).
        to_return(status: response_code, body: body)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
      let(:parameters) { { 'some-key' => 'some-value' } }
      let(:body) { { 'parameters' => parameters }.to_json }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 200,
            response_object: parameters }.freeze
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end
    end

    context 'when the service broker returns parameters with mixed data types' do
      let(:body) { "{\"parameters\":#{parameters_mixed_data_types_as_json_string}}" }

      it 'correctly parses all data types and returns the desired JSON string' do
        allow_any_instance_of(VCAP::CloudController::ServiceInstanceRead).to receive(:fetch_parameters).and_wrap_original do |m, instance|
          result = m.call(instance)
          expect(result).to eq(parameters_mixed_data_types_as_hash) # correct internal representation
          result
        end

        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(last_response).to match(/#{Regexp.escape(parameters_mixed_data_types_as_json_string)}/)
      end
    end

    it 'sends the correct request to the service broker' do
      get "/v3/service_instances/#{instance.guid}/parameters", nil, headers_for(user, scopes: %w[cloud_controller.admin])

      encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
      expect(a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
        with(
          headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" }
        )).to have_been_made.once
    end

    context 'when the instance does not support retrievable instances' do
      let(:service) { VCAP::CloudController::Service.make(instances_retrievable: false) }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
                                                               'detail' => 'This service does not support fetching service instance parameters.',
                                                               'title' => 'CF-ServiceFetchInstanceParametersNotSupported',
                                                               'code' => 120_004
                                                             }))
      end
    end

    context 'when the broker returns no parameters' do
      it 'returns an empty object' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to match_json_response({})
      end
    end

    context 'when the broker returns invalid parameters' do
      let(:body) { { 'parameters' => 'not valid' }.to_json }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-ServiceBrokerResponseMalformed',
                                                               'code' => 10_001
                                                             }))
      end
    end

    context 'when the broker returns invalid JSON' do
      let(:body) { 'this is not json' }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-ServiceBrokerResponseMalformed',
                                                               'code' => 10_001
                                                             }))
      end
    end

    context 'when the broker returns a non-200 response code' do
      let(:response_code) { 500 }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-ServiceBrokerBadResponse',
                                                               'code' => 10_001
                                                             }))
      end
    end

    context 'when the broker returns a 422 (update in progress) response code' do
      let(:response_code) { 422 }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(502)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-ServiceBrokerBadResponse',
                                                               'code' => 10_001
                                                             }))
      end
    end

    context 'when the instance is shared' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, service_plan: service_plan) }
        let(:parameters) { { 'some-key' => 'some-value' } }
        let(:body) { { 'parameters' => parameters }.to_json }
        let(:guid) { instance.guid }

        before do
          instance.add_shared_space(space)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            { code: 200,
              response_object: parameters }.freeze
          )

          h['space_supporter'] = h['space_developer'] = h['space_manager'] = h['space_auditor'] = h['org_manager'] = { code: 403 }
          h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
          h
        end
      end
    end

    context 'when the instance does not exist' do
      it 'responds with 404' do
        get '/v3/service_instances/does-not-exist/parameters', nil, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the last operation state of the service instance is create in progress' do
      before do
        instance.save_with_new_operation({}, { type: 'create', state: 'in progress' })
      end

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(409)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-AsyncServiceInstanceOperationInProgress',
                                                               'code' => 60_016
                                                             }))
      end
    end

    context 'when the last operation state of the service instance is create succeeded' do
      before do
        instance.save_with_new_operation({}, { type: 'create', state: 'succeeded' })
      end

      it 'returns the parameters' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the last operation state of the service instance is create failed' do
      before do
        instance.save_with_new_operation({}, { type: 'create', state: 'failed' })
      end

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(404)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-ResourceNotFound',
                                                               'code' => 10_010
                                                             }))
      end
    end

    context 'when the last operation state of the service instance is update in progress' do
      before do
        instance.save_with_new_operation({}, { type: 'update', state: 'in progress' })
      end

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(409)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-AsyncServiceInstanceOperationInProgress',
                                                               'code' => 60_016
                                                             }))
      end
    end

    context 'when the last operation state of the service instance is update succeeded' do
      before do
        instance.save_with_new_operation({}, { type: 'update', state: 'succeeded' })
      end

      it 'returns the parameters' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the last operation state of the service instance is update failed' do
      before do
        instance.save_with_new_operation({}, { type: 'update', state: 'failed' })
      end

      it 'returns the parameters' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the last operation state of the service instance is delete in progress' do
      before do
        instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
      end

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(409)
        expect(parsed_response['errors']).to include(include({
                                                               'title' => 'CF-AsyncServiceInstanceOperationInProgress',
                                                               'code' => 60_016
                                                             }))
      end
    end

    context 'when the last operation state of the service instance is delete failed' do
      before do
        instance.save_with_new_operation({}, { type: 'delete', state: 'failed' })
      end

      it 'returns the parameters' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the instance is user-provided' do
      it 'responds with 404' do
        upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space:)

        get "/v3/service_instances/#{upsi.guid}/parameters", nil, admin_headers

        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
                                                               'detail' => 'This service does not support fetching service instance parameters.',
                                                               'title' => 'CF-ServiceFetchInstanceParametersNotSupported',
                                                               'code' => 120_004
                                                             }))
      end
    end
  end

end
