require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make }
  let!(:org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: org.guid) }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let!(:space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'baz', value: 'wow', space: space) }
  let(:another_space) { VCAP::CloudController::Space.make }

  describe 'GET /v3/service_instances/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}", nil, user_headers } }

    context 'no such instance' do
      let(:guid) { 'no-such-guid' }

      let(:expected_codes_and_responses) do
        Hash.new(code: 404)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'managed service instance' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(
          create_managed_json(instance)
        )
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'user-provided service instance' do
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(
          create_user_provided_json(instance)
        )
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
        responses_for_space_restricted_single_endpoint(
          create_managed_json(instance)
        )
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'fields' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
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

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
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

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end

      it 'can include service plan guid and name fields' do
        get "/v3/service_instances/#{guid}?fields[service_plan]=guid,name", nil, admin_headers

        expect(last_response).to have_status_code(200)

        included = {
          service_plans: [
            {
              guid: instance.service_plan.guid,
              name: instance.service_plan.name,
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
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
              documentation_url: 'https://some.url.for.docs/',
            }
          ],
          service_brokers: [
            {
              name: instance.service_plan.service.service_broker.name,
              guid: instance.service_plan.service.service_broker.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end
    end
  end

  describe 'GET /v3/service_instances' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_instances', nil, user_headers } }

    it_behaves_like 'list query endpoint' do
      let(:user_header) { admin_headers }
      let(:request) { 'v3/service_instances' }
      let(:message) { VCAP::CloudController::ServiceInstancesListMessage }

      let(:params) do
        {
          names: ['foo', 'bar'],
          space_guids: ['foo', 'bar'],
          organization_guids: ['org-1', 'org-2'],
          per_page: '10',
          page: 2,
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          type: 'managed',
          service_plan_guids: ['guid-1', 'guid-2'],
          service_plan_names: ['plan-1', 'plan-2'],
          fields: { 'space.organization' => 'name' },
          guids: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
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
      let!(:msi_1) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let!(:msi_2) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space) }
      let!(:upsi_1) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
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

        it 'filters by organization guids' do
          get "/v3/service_instances?organization_guids=#{another_space.organization.guid}", nil, admin_headers
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

        it 'filters by type' do
          get '/v3/service_instances?type=managed', nil, admin_headers
          check_filtered_instances(
            create_managed_json(msi_1),
            create_managed_json(msi_2),
            create_managed_json(ssi),
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

          expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
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

          expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
        end
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::ServiceInstanceListFetcher).to receive(:fetch).with(
          an_instance_of(VCAP::CloudController::ServiceInstancesListMessage),
          hash_including(eager_loaded_associations: [:labels, :annotations, :space, :service_instance_operation, :service_plan_sti_eager_load])
        ).and_call_original

        get '/v3/service_instances', nil, admin_headers
        expect(last_response).to have_status_code(200)
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::ServiceInstance }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/service_instances?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'GET /v3/service_instances/:guid/credentials' do
    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/credentials", nil, user_headers } }
      let(:credentials) { { 'fake-key' => 'fake-value' } }
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, credentials: credentials) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: credentials,
        )

        h['global_auditor'] = { code: 403 }
        h['space_manager'] = { code: 403 }
        h['space_auditor'] = { code: 403 }
        h['org_manager'] = { code: 403 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
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
      msi = VCAP::CloudController::ManagedServiceInstance.make(space: space)
      get "/v3/service_instances/#{msi.guid}/credentials", nil, admin_headers
      expect(last_response).to have_status_code(404)
    end
  end

  describe 'GET /v3/service_instances/:guid/parameters' do
    let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
    let(:body) { {}.to_json }
    let(:response_code) { 200 }

    before do
      stub_request(:get, %r{#{instance.service.service_broker.broker_url}/v2/service_instances/#{guid_pattern}}).
        with(basic_auth: basic_auth(service_broker: instance.service.service_broker)).
        to_return(status: response_code, body: body)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
      let(:parameters) { { 'some-key' => 'some-value' } }
      let(:body) { { 'parameters' => parameters }.to_json }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: parameters,
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end
    end

    it 'sends the correct request to the service broker' do
      get "/v3/service_instances/#{instance.guid}/parameters", nil, headers_for(user, scopes: %w(cloud_controller.admin))

      encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
      expect(a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
        with(
          headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
        )
      ).to have_been_made.once
    end

    context 'when the instance does not support retrievable instances' do
      let(:service) { VCAP::CloudController::Service.make(instances_retrievable: false) }

      it 'fails with an explanatory error' do
        get "/v3/service_instances/#{instance.guid}/parameters", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
          'detail' => 'This service does not support fetching service instance parameters.',
          'title' => 'CF-ServiceFetchInstanceParametersNotSupported',
          'code' => 120004,
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
          'code' => 10001,
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
          'code' => 10001,
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
          'code' => 10001,
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
          'code' => 10001,
        }))
      end
    end

    context 'when the instance is shared' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{guid}/parameters", nil, user_headers } }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, service_plan: service_plan) }
        let(:parameters) { { 'some-key' => 'some-value' } }
        let(:body) { { 'parameters' => parameters }.to_json }
        let(:guid) { instance.guid }

        before do
          instance.add_shared_space(space)
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: parameters,
          )

          h['space_developer'] = { code: 403 }
          h['space_manager'] = { code: 403 }
          h['space_auditor'] = { code: 403 }
          h['org_manager'] = { code: 403 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
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

    context 'when the instance is user-provided' do
      it 'responds with 404' do
        upsi = VCAP::CloudController::UserProvidedServiceInstance.make(space: space)

        get "/v3/service_instances/#{upsi.guid}/parameters", nil, admin_headers

        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(include({
          'detail' => 'This service does not support fetching service instance parameters.',
          'title' => 'CF-ServiceFetchInstanceParametersNotSupported',
          'code' => 120004,
        }))
      end
    end
  end

  describe 'POST /v3/service_instances' do
    let(:api_call) { lambda { |user_headers| post '/v3/service_instances', request_body.to_json, user_headers } }
    let(:space_guid) { space.guid }

    let(:name) { Sham.name }
    let(:type) { 'user-provided' }
    let(:request_body_additions) { {} }
    let(:request_body) do
      {
        type: type,
        name: name,
        relationships: {
          space: {
            data: {
              guid: space_guid
            }
          }
        }
      }.merge(request_body_additions)
    end

    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:expected_codes_and_responses) { responses_for_space_restricted_create_endpoint(success_code: 201) }
    end

    it_behaves_like 'permissions for create endpoint when organization is suspended', 201 do
      let(:expected_codes) {}
    end

    context 'when service_instance_creation flag is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.create(name: 'service_instance_creation', enabled: false)
      end

      it 'makes non_admins unable to create any type of service' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => 'Feature Disabled: service_instance_creation',
            'title' => 'CF-FeatureDisabled',
            'code' => 330002,
          })
        )
      end

      it 'does not impact admins ability create services' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(201)
      end
    end

    context 'when the request body is invalid' do
      let(:request_body) { { type: 'foo' } }

      it 'says the message is unprocessable' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => "Relationships 'relationships' is not an object, Type must be one of 'managed', 'user-provided', Name must be a string, Name can't be blank",
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          })
        )
      end
    end

    context 'when the space is not readable' do
      it 'fails saying the space cannot be found' do
        request_body[:relationships][:space][:data][:guid] = VCAP::CloudController::Space.make.guid

        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => 'Invalid space. Ensure that the space exists and you have access to it.',
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          })
        )
      end
    end

    context 'user-provided service instance' do
      let(:request_body) do
        {
          type: type,
          name: name,
          relationships: {
            space: {
              data: {
                guid: space_guid
              }
            }
          },
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          tags: %w(foo bar baz),
          syslog_drain_url: 'https://syslog.com/drain',
          route_service_url: 'https://route.com/service',
          metadata: {
            annotations: {
              foo: 'bar'
            },
            labels: {
              baz: 'qux'
            }
          }
        }
      end

      it 'responds with the created object' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(201)
        expect(parsed_response).to match_json_response(
          create_user_provided_json(
            VCAP::CloudController::ServiceInstance.last,
            labels: { baz: 'qux' },
            annotations: { foo: 'bar' },
            last_operation: {
              type: 'create',
              state: 'succeeded',
              description: 'Operation succeeded',
              created_at: iso8601,
              updated_at: iso8601,
            }
          )
        )
      end

      it 'creates a service instance in the database' do
        api_call.call(space_dev_headers)

        instance = VCAP::CloudController::ServiceInstance.last

        expect(instance.name).to eq(name)
        expect(instance.syslog_drain_url).to eq('https://syslog.com/drain')
        expect(instance.route_service_url).to eq('https://route.com/service')
        expect(instance.tags).to contain_exactly('foo', 'bar', 'baz')
        expect(instance.credentials).to match({ 'foo' => 'bar', 'baz' => 'qux' })
        expect(instance.space).to eq(space)
        expect(instance.last_operation.type).to eq('create')
        expect(instance.last_operation.state).to eq('succeeded')
        expect(instance).to have_annotations({ prefix: nil, key: 'foo', value: 'bar' })
        expect(instance).to have_labels({ prefix: nil, key: 'baz', value: 'qux' })
      end

      context 'when the name has already been taken' do
        it 'fails when the same name is already used in this space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The service instance name is taken: #{name}.",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end

        it 'succeeds when the same name is used in another space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: another_space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(201)
        end
      end

      context 'when the route is not https' do
        it 'returns an error' do
          request_body[:route_service_url] = 'http://banana.example.com'
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => 'Route service url must be https',
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end
    end

    context 'managed service instance' do
      let(:type) { 'managed' }
      let(:maintenance_info) do
        {
          version: '1.2.3',
          description: 'amazing version'
        }
      end
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, maintenance_info: maintenance_info) }
      let(:service_plan_guid) { service_plan.guid }
      let(:request_body) do
        {
          type: type,
          name: name,
          relationships: {
            space: {
              data: {
                guid: space_guid
              }
            },
            service_plan: {
              data: {
                guid: service_plan_guid
              }
            }
          },
          parameters: {
            foo: 'bar',
            baz: 'qux'
          },
          tags: %w(foo bar baz),
          metadata: {
            annotations: {
              foo: 'bar',
              'pre.fix/wow': 'baz'
            },
            labels: {
              baz: 'qux'
            }
          }
        }
      end
      let(:instance) { VCAP::CloudController::ServiceInstance.last }
      let(:job) { VCAP::CloudController::PollableJobModel.last }

      it 'creates a service instance in the database' do
        api_call.call(space_dev_headers)

        expect(instance.name).to eq(name)
        expect(instance.tags).to contain_exactly('foo', 'bar', 'baz')
        expect(instance.space).to eq(space)
        expect(instance.service_plan).to eq(service_plan)

        expect(instance).to have_annotations({ prefix: nil, key: 'foo', value: 'bar' }, { prefix: 'pre.fix', key: 'wow', value: 'baz' })
        expect(instance).to have_labels({ prefix: nil, key: 'baz', value: 'qux' })

        expect(instance.last_operation.type).to eq('create')
        expect(instance.last_operation.state).to eq('in progress')
      end

      it 'responds with job resource' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(202)
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_instance.create')
        expect(job.resource_guid).to eq(instance.guid)
        expect(job.resource_type).to eq('service_instances')
      end

      context 'when the name has already been taken' do
        it 'fails when the same name is already used in this space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The service instance name is taken: #{name}.",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end

        it 'succeeds when the same name is used in another space' do
          VCAP::CloudController::ServiceInstance.make(name: name, space: another_space)

          api_call.call(admin_headers)
          expect(last_response).to have_status_code(202)
        end
      end

      context 'when the plan is org-restricted' do
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

        before do
          VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan, organization: org)
        end

        it 'can be created in a space in that org' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(202)
          expect(instance.name).to eq(name)
        end
      end

      describe 'unavailable broker' do
        context 'when the service broker does not have state (v2 brokers)' do
          let(:service_broker) { service_plan.service_broker }

          it 'creates a service instance' do
            service_broker.update(state: '')
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(202)
          end
        end

        context 'when there is an operation in progress for the service broker' do
          let(:service_broker) { service_plan.service_broker }

          before do
            service_broker.update(state: broker_state)
          end

          context 'when the service broker is being deleted' do
            let(:broker_state) { VCAP::CloudController::ServiceBrokerStateEnum::DELETE_IN_PROGRESS }
            it 'fails to create a service instance' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => 'The service instance cannot be created because there is an operation in progress for the service broker.',
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end

          context 'when the service broker is synchronising the catalog' do
            let(:broker_state) { VCAP::CloudController::ServiceBrokerStateEnum::SYNCHRONIZING }
            it 'fails to create a service instance' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => 'The service instance cannot be created because there is an operation in progress for the service broker.',
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end
        end
      end

      describe 'service plan checks' do
        context 'does not exist' do
          let(:service_plan_guid) { 'does-not-exist' }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'not readable by the user' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'not enabled in that org' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }

          it 'fails saying the plan is invalid' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              }))
          end
        end

        context 'not active' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: false) }

          it 'fails saying the plan is invalid' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'space-scoped plan from a different space' do
          let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: another_space) }
          let(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, active: true, public: false) }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end
      end

      describe 'the pollable job' do
        let(:request_body_additions) { { parameters: { foo: 'bar', baz: 'qux' } } }
        let(:broker_response) { { dashboard_url: 'http://dashboard.url' } }
        let(:broker_status_code) { 201 }
        let(:last_operation_status_code) { 200 }
        let(:last_operation_response) { { state: 'in progress' } }

        before do
          api_call.call(space_dev_headers)
          instance = VCAP::CloudController::ServiceInstance.last
          stub_request(:put, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
            with(query: { 'accepts_incomplete' => true }).
            to_return(status: broker_status_code, body: broker_response.to_json, headers: {})

          stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
            with(
              query: {
                operation: 'task12',
                service_id: service_plan.service.unique_id,
                plan_id: service_plan.unique_id,
              }).
            to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
        end

        it 'sends a provision request with the right arguments to the service broker' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(a_request(:put, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
            with(
              query: { accepts_incomplete: true },
              body: {
                service_id: service_plan.service.unique_id,
                plan_id: service_plan.unique_id,
                context: {
                  platform: 'cloudfoundry',
                  organization_guid: org.guid,
                  organization_name: org.name,
                  organization_annotations: { 'pre.fix/foo': 'bar' },
                  space_guid: space.guid,
                  space_name: space.name,
                  space_annotations: { 'pre.fix/baz': 'wow' },
                  instance_name: instance.name,
                  instance_annotations: { 'pre.fix/wow': 'baz' }
                },
                organization_guid: org.guid,
                space_guid: space.guid,
                parameters: {
                  foo: 'bar',
                  baz: 'qux'
                },
                maintenance_info: maintenance_info
              },
              headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
            )
          ).to have_been_made.once
        end

        context 'when the provision completes synchronously' do
          it 'marks the service instance as created' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(instance.dashboard_url).to eq('http://dashboard.url')
            expect(instance.last_operation.type).to eq('create')
            expect(instance.last_operation.state).to eq('succeeded')
          end

          it 'completes' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
          end

          context 'when the broker responds with an error' do
            let(:broker_status_code) { 400 }

            it 'marks the service instance as failed' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('failed')
              expect(instance.last_operation.description).to include('Status Code: 400 Bad Request')
            end

            it 'completes with failure' do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end
          end
        end

        context 'when the provision is asynchronous' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'task12' } }

          it 'marks the job state as polling' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'calls last operation immediately' do
            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(
              a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id,
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
                )
            ).to have_been_made.once
          end

          it 'enqueues the next fetch last operation job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          context 'when last operation eventually returns `create succeeded`' do
            let(:dashboard_url) { '' }

            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id,
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

              stub_request(:get, "#{instance.service.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
                to_return(status: 200, body: { dashboard_url: dashboard_url }.to_json)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'sets the service instance last operation to create succeeded' do
              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('succeeded')
            end

            context 'it fetches dashboard url' do
              let(:service) { VCAP::CloudController::Service.make(instances_retrievable: true) }
              let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, service: service) }
              let(:dashboard_url) { 'http:/some-new-dashboard-url.com' }

              it 'sets the service instance dashboard url' do
                instance.reload

                expect(instance.dashboard_url).to eq(dashboard_url)
              end
            end
          end

          context 'when last operation eventually returns `create failed`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_plan.service.unique_id,
                    plan_id: service_plan.unique_id,
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'failed' }.to_json, headers: {})

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to create failed' do
              expect(instance.last_operation.type).to eq('create')
              expect(instance.last_operation.state).to eq('failed')
            end
          end
        end

        describe 'volume mount and route service checks' do
          context 'when volume mount required' do
            let(:service_offering) { VCAP::CloudController::Service.make(requires: %w(volume_mount)) }
            let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

            context 'volume mount disabled' do
              before do
                TestConfig.config[:volume_services_enabled] = false
              end

              it 'warns' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::VOLUME_SERVICE_WARNING)
              end
            end

            context 'volume mount enabled' do
              before do
                TestConfig.config[:volume_services_enabled] = true
              end

              it 'does not warn' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings).to be_empty
              end
            end
          end

          context 'when route forwarding required' do
            let(:service_offering) { VCAP::CloudController::Service.make(requires: %w(route_forwarding)) }
            let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

            context 'route forwarding disabled' do
              before do
                TestConfig.config[:route_services_enabled] = false
              end

              it 'warns' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::ROUTE_SERVICE_WARNING)
              end
            end

            context 'route forwarding enabled' do
              before do
                TestConfig.config[:route_services_enabled] = true
              end

              it 'does not warn' do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)

                job = VCAP::CloudController::PollableJobModel.last
                expect(job.warnings).to be_empty
              end
            end
          end
        end
      end

      describe 'quotas restrictions' do
        describe 'space quotas' do
          context 'when the total services quota has been reached' do
            before do
              quota = VCAP::CloudController::SpaceQuotaDefinition.make(total_services: 1, organization: org)
              quota.add_space(space)

              VCAP::CloudController::ManagedServiceInstance.make(space: space)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => "You have exceeded your space's services limit.",
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end

          context 'when the paid services quota has been reached' do
            let!(:service_plan) { VCAP::CloudController::ServicePlan.make(free: false, public: true, active: true) }
            before do
              quota = VCAP::CloudController::SpaceQuotaDefinition.make(non_basic_services_allowed: false, organization: org)
              quota.add_space(space)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => 'The service instance cannot be created because paid service plans are not allowed for your space.',
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end
        end

        describe 'organization quotas' do
          context 'when the total services quota has been reached' do
            before do
              quota = VCAP::CloudController::QuotaDefinition.make(total_services: 1)
              quota.add_organization(org)
              VCAP::CloudController::ManagedServiceInstance.make(space: space)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => "You have exceeded your organization's services limit.",
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end

          context 'when the paid services quota has been reached' do
            let!(:service_plan) { VCAP::CloudController::ServicePlan.make(free: false, public: true, active: true) }
            before do
              quota = VCAP::CloudController::QuotaDefinition.make(non_basic_services_allowed: false)
              quota.add_organization(org)
            end

            it 'returns an error' do
              api_call.call(space_dev_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => 'The service instance cannot be created because paid service plans are not allowed.',
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end
        end
      end
    end
  end

  describe 'PATCH /v3/service_instances/:guid' do
    let(:api_call) { lambda { |user_headers| patch "/v3/service_instances/#{guid}", request_body.to_json, user_headers } }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let(:request_body) do
      {}
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:guid) { VCAP::CloudController::ServiceInstance.make(space: space).guid }
      let(:expected_codes_and_responses) { responses_for_space_restricted_update_endpoint(success_code: 200) }
    end

    it_behaves_like 'permissions for update endpoint when organization is suspended', 200 do
      let(:guid) { VCAP::CloudController::ServiceInstance.make(space: space).guid }
      let(:expected_codes) {}
    end

    context 'service instance does not exist' do
      let(:guid) { 'no-such-instance' }

      it 'fails saying the service instance is not found (404)' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(404)
        expect(parsed_response['errors']).to include(
          include({
            'detail' => 'Service instance not found',
            'title' => 'CF-ResourceNotFound',
            'code' => 10010,
          })
        )
      end
    end

    context 'managed service instance' do
      describe 'updates that do not require broker communication' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w(foo bar),
            space: space
          )
          si.annotation_ids = [
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
          ]
          si.label_ids = [
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          ]
          si
        end

        let(:guid) { service_instance.guid }

        let(:request_body) do
          {
            tags: %w(baz quz),
            metadata: {
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/to_delete': nil
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/to_delete': nil
              }
            }
          }
        end

        it 'responds synchronously' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response(
            create_managed_json(
              service_instance,
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/tail': 'fluffy'
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/fox': 'bushy'
              },
              last_operation: {
                created_at: iso8601,
                updated_at: iso8601,
                description: nil,
                state: 'succeeded',
                type: 'update'
              },
              tags: %w(baz quz)
            )
          )
        end

        it 'updates the service instance' do
          api_call.call(space_dev_headers)

          service_instance.reload
          expect(service_instance.tags).to eq(%w(baz quz))

          expect(service_instance).to have_annotations(
            { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
            { prefix: nil, key: 'potato', value: 'idaho' },
            { prefix: nil, key: 'style', value: 'mashed' },
          )
          expect(service_instance).to have_labels(
            { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
            { prefix: nil, key: 'potato', value: 'yam' },
            { prefix: nil, key: 'style', value: 'baked' }
          )

          expect(service_instance.last_operation.type).to eq('update')
          expect(service_instance.last_operation.state).to eq('succeeded')
        end
      end

      describe 'updates that require broker communication' do
        let(:service_offering) { VCAP::CloudController::Service.make }
        let(:original_service_plan) do
          VCAP::CloudController::ServicePlan.make(
            service: service_offering,
            plan_updateable: true,
            maintenance_info: { version: '1.1.1' }
          )
        end
        let(:new_service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let(:original_maintenance_info) { { version: '1.1.0' } }
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w(foo bar),
            space: space,
            service_plan: original_service_plan,
            maintenance_info: original_maintenance_info
          )
          si.annotation_ids = [
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
          ]
          si.label_ids = [
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          ]
          si
        end
        let(:guid) { service_instance.guid }
        let(:request_body) do
          {
            name: 'new-name',
            relationships: {
              service_plan: {
                data: {
                  guid: new_service_plan.guid
                }
              }
            },
            parameters: {
              foo: 'bar',
              baz: 'qux'
            },
            tags: %w(baz quz),
            metadata: {
              labels: {
                potato: 'yam',
                style: 'baked',
                'pre.fix/to_delete': nil
              },
              annotations: {
                potato: 'idaho',
                style: 'mashed',
                'pre.fix/to_delete': nil
              }
            }
          }
        end
        let(:job) { VCAP::CloudController::PollableJobModel.last }

        it 'responds with a pollable job' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(202)
          expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('service_instance.update')
          expect(job.resource_guid).to eq(service_instance.guid)
          expect(job.resource_type).to eq('service_instances')
        end

        it 'updates the last operation' do
          api_call.call(space_dev_headers)

          expect(service_instance.last_operation.type).to eq('update')
          expect(service_instance.last_operation.state).to eq('in progress')
        end

        it 'does not immediately update the service instance' do
          api_call.call(space_dev_headers)

          service_instance.reload
          expect(service_instance.reload.tags).to eq(%w(foo bar))

          expect(service_instance).to have_annotations(
            { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
            { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
          )
          expect(service_instance).to have_labels(
            { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
            { prefix: 'pre.fix', key: 'tail', value: 'fluffy' }
          )
        end

        describe 'the pollable job' do
          let(:broker_response) { { dashboard_url: 'http://new-dashboard.url' } }
          let(:broker_status_code) { 200 }

          before do
            api_call.call(space_dev_headers)

            instance = VCAP::CloudController::ServiceInstance.last

            stub_request(:patch, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
              with(query: { 'accepts_incomplete' => true }).
              to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
          end

          it 'sends a UPDATE request with the right arguments to the service broker' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            expect(
              a_request(:patch, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}").
                with(
                  query: { accepts_incomplete: true },
                  body: {
                    service_id: new_service_plan.service.unique_id,
                    plan_id: new_service_plan.unique_id,
                    previous_values: {
                      plan_id: original_service_plan.unique_id,
                      service_id: original_service_plan.service.unique_id,
                      organization_id: org.guid,
                      space_id: space.guid,
                      maintenance_info: { version: '1.1.0' }
                    },
                    context: {
                      platform: 'cloudfoundry',
                      organization_guid: org.guid,
                      organization_name: org.name,
                      organization_annotations: { 'pre.fix/foo': 'bar' },
                      space_guid: space.guid,
                      space_name: space.name,
                      space_annotations: { 'pre.fix/baz': 'wow' },
                      instance_name: 'new-name',
                    },
                    parameters: {
                      foo: 'bar',
                      baz: 'qux'
                    },
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
                )
            ).to have_been_made.once
          end

          context 'when the update completes synchronously' do
            it 'marks the service instance as updated' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              service_instance.reload
              expect(service_instance.dashboard_url).to eq('http://new-dashboard.url')
              expect(service_instance.last_operation.type).to eq('update')
              expect(service_instance.last_operation.state).to eq('succeeded')
              expect(service_instance.maintenance_info).to eq(new_service_plan.maintenance_info)
            end

            it 'marks the job as complete' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            context 'when the broker responds with an error' do
              let(:broker_status_code) { 400 }

              it 'marks the service instance as failed' do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
                expect(service_instance.last_operation.description).to include('Status Code: 400 Bad Request')
              end

              it 'marks the job as failed' do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)

                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              end
            end
          end

          context 'when the update is asynchronous' do
            let(:broker_status_code) { 202 }
            let(:broker_response) { { operation: 'task12' } }
            let(:last_operation_status_code) { 200 }
            let(:last_operation_response) { { state: 'in progress' } }
            let(:dashboard_url) {}

            before do
              stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'task12',
                    service_id: service_instance.service_plan.service.unique_id,
                    plan_id: service_instance.service_plan.unique_id,
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})

              stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}").
                to_return(status: 200, body: { dashboard_url: dashboard_url }.to_json)
            end

            it 'marks the job state as polling' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
            end

            it 'calls last operation immediately' do
              encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(
                a_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id,
                    },
                    headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
                  )
              ).to have_been_made.once
            end

            it 'enqueues the next fetch last operation job' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)
            end

            context 'when last operation eventually returns `update succeeded`' do
              let(:last_operation_status_code) { 200 }
              let(:last_operation_response) { { state: 'in progress' } }

              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id,
                    }).
                  to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                  to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

                Timecop.freeze(Time.now + 1.hour) do
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'completes the job' do
                updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
                expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
              end

              it 'sets the service instance last operation to create succeeded' do
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('succeeded')
              end

              context 'it fetches dashboard url' do
                let(:service_offering) { VCAP::CloudController::Service.make(instances_retrievable: true) }
                let(:dashboard_url) { 'http:/some-new-dashboard-url.com' }

                it 'sets the service instance dashboard url' do
                  service_instance.reload
                  expect(service_instance.dashboard_url).to eq(dashboard_url)
                end
              end
            end

            context 'when last operation eventually returns `update failed`' do
              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id,
                    }).
                  to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                  to_return(status: 200, body: { state: 'failed' }.to_json, headers: {})

                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

                Timecop.freeze(Time.now + 1.hour) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
                end
              end

              it 'completes the job' do
                updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
                expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              end

              it 'sets the service instance last operation to update failed' do
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
              end
            end

            context 'when last operation eventually returns error 400' do
              before do
                stub_request(:get, "#{service_instance.service_broker.broker_url}/v2/service_instances/#{service_instance.guid}/last_operation").
                  with(
                    query: {
                      operation: 'task12',
                      service_id: service_instance.service_plan.service.unique_id,
                      plan_id: service_instance.service_plan.unique_id,
                    }).
                  to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                  to_return(status: 400, body: {}.to_json, headers: {})

                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

                Timecop.freeze(Time.now + 1.hour) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
                end
              end

              it 'completes the job' do
                updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
                expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
              end

              it 'sets the service instance last operation to update failed' do
                expect(service_instance.last_operation.type).to eq('update')
                expect(service_instance.last_operation.state).to eq('failed')
              end

              it 'does not update the instance' do
                #  TODO maybe look in the client to add this test and make sure what it returns? so we can test at a unit level in the job as well
                service_instance.reload
                expect(service_instance.reload.tags).to eq(%w(foo bar))
                expect(service_instance.service_plan).to eq(original_service_plan)
                expect(service_instance).to have_annotations(
                  { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
                  { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
                )
                expect(service_instance).to have_labels(
                  { prefix: 'pre.fix', key: 'to_delete', value: 'value' },
                  { prefix: 'pre.fix', key: 'tail', value: 'fluffy' }
                )
              end

              context 'when changing maintenance_info' do
                let(:request_body) do
                  {
                    maintenance_info: { version: '1.1.1' },
                  }
                end

                it 'does not update the instance' do
                  service_instance.reload
                  expect(service_instance.maintenance_info.symbolize_keys).to eq(original_maintenance_info)
                end
              end
            end
          end

          context 'changing maintenance_info alongside other parameters' do
            let(:new_maintenance_info) { { version: '1.1.1' } }
            let(:request_body) do
              {
                name: 'new-name',
                maintenance_info: new_maintenance_info,
                tags: %w(baz quz),
              }
            end

            it 'modifies the instance' do
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              service_instance.reload
              expect(service_instance.maintenance_info.symbolize_keys).to eq(new_maintenance_info)
              expect(service_instance.last_operation.type).to eq('update')
              expect(service_instance.last_operation.state).to eq('succeeded')
              expect(service_instance.name).to eq('new-name')
              expect(service_instance.tags).to include('baz', 'quz')
            end
          end
        end
      end

      describe 'no changes requested' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w(foo bar),
            space: space
          )
          si
        end

        let(:guid) { service_instance.guid }

        it 'updates the instance synchronously' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(200)
          expect(parsed_response).to match_json_response(
            create_managed_json(
              service_instance,
              last_operation: {
                created_at: iso8601,
                updated_at: iso8601,
                description: nil,
                state: 'succeeded',
                type: 'update'
              },
              tags: %w(foo bar)
            )
          )
        end
      end

      describe 'maintenance_info checks' do
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            space: space,
            service_plan: service_plan
          )
        end
        let(:guid) { service_instance.guid }

        context 'changing maintenance_info when the plan does not support it' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: true, service: service_offering) }
          let(:service_plan_guid) { service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '3.1.0',
              }
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => 'The service broker does not support upgrades for service instances created from this plan.',
                  'code' => 10008,
                }
              )
            )
          end
        end

        context 'maintenance_info conflict' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) {
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.1.0' }
            )
          }
          let(:service_plan_guid) { service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '2.2.0',
              }
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => include('maintenance_info.version requested is invalid'),
                  'code' => 10008,
                }
              )
            )
          end
        end

        context 'changing maintenance_info alongside plan' do
          let(:service_offering) { VCAP::CloudController::Service.make(plan_updateable: true) }
          let(:service_plan) {
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.2.0' }
            )
          }

          let(:new_service_plan) {
            VCAP::CloudController::ServicePlan.make(
              public: true,
              active: true,
              service: service_offering,
              maintenance_info: { version: '2.1.0' }
            )
          }

          let(:new_service_plan_guid) { new_service_plan.guid }

          let(:request_body) do
            {
              maintenance_info: {
                version: '2.2.0',
              },
              relationships: {
                service_plan: {
                  data: {
                    guid: new_service_plan_guid
                  }
                }
              },
            }
          end

          it 'fails with a descriptive message' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include(
                {
                  'title' => 'CF-UnprocessableEntity',
                  'detail' => include('maintenance_info should not be changed when switching to different plan.'),
                  'code' => 10008,
                }
              )
            )
          end
        end
      end

      describe 'service plan checks' do
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w(foo bar),
            space: space
          )
        end
        let(:guid) { service_instance.guid }

        let(:request_body) do
          {
            relationships: {
              service_plan: {
                data: {
                  guid: service_plan_guid
                }
              }
            }
          }
        end

        context 'does not exist' do
          let(:service_plan_guid) { 'does-not-exist' }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'not readable by the user' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: false, active: true) }
          let(:service_plan_guid) { service_plan.guid }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'not available' do
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(public: true, active: false) }
          let(:service_plan_guid) { service_plan.guid }

          it 'fails saying the plan is invalid' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'space-scoped plan from a different space' do
          let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: another_space) }
          let(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, active: true, public: false) }
          let(:service_plan_guid) { service_plan.guid }

          it 'fails saying the plan is invalid' do
            api_call.call(space_dev_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'relates to a different service offering' do
          let(:service_plan_guid) { VCAP::CloudController::ServicePlan.make.guid }

          it 'fails saying the plan relates to a different service offering' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(400)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'service plan relates to a different service offering',
                'title' => 'CF-InvalidRelation',
                'code' => 1002,
              })
            )
          end
        end
      end

      describe 'name checks' do
        context 'name is already used in this space' do
          let(:guid) { service_instance.guid }
          let!(:service_instance) do
            VCAP::CloudController::ManagedServiceInstance.make(
              tags: %w(foo bar),
              space: space,
            )
          end

          let!(:name) { 'test' }
          let!(:other_si) { VCAP::CloudController::ServiceInstance.make(name: name, space: space) }
          let(:request_body) { { name: name } }

          it 'should fail' do
            api_call.call(admin_headers)

            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => "The service instance name is taken: #{name}",
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end
      end

      describe 'invalid request' do
        let!(:service_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            tags: %w(foo bar),
            space: space
          )
          si
        end

        let(:guid) { service_instance.guid }
        let(:request_body) do
          {
            relationships: {
              space: {
                data: {
                  guid: 'some-space'
                }
              }
            }
          }
        end

        it 'should fail' do
          api_call.call(space_dev_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => include("Relationships Unknown field(s): 'space'"),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end

      describe 'when the SI plan is no longer active' do
        let(:version) { { version: '2.0.0' } }
        let(:service_offering) { VCAP::CloudController::Service.make }
        let(:service_plan) {
          VCAP::CloudController::ServicePlan.make(
            public: true,
            active: false,
            maintenance_info: version,
            service: service_offering)
        }
        let!(:service_instance) {
          VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan)
        }
        let(:guid) { service_instance.guid }

        context 'and the request is updating parameters' do
          let(:request_body) { { parameters: { foo: 'bar', baz: 'qux' } } }

          it 'fails with a plan inaccessible message' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Cannot update parameters of a service instance that belongs to inaccessible plan',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'and the request is updating maintenance_info' do
          let(:request_body) { { maintenance_info: { version: '2.0.0' } } }

          it 'fails with a plan inaccessible message' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(422)
            expect(parsed_response['errors']).to include(
              include({
                'detail' => 'Cannot update maintenance_info of a service instance that belongs to inaccessible plan',
                'title' => 'CF-UnprocessableEntity',
                'code' => 10008,
              })
            )
          end
        end

        context 'and the request is updating the SI name' do
          let(:request_body) { { name: 'new-name' } }

          context 'and the service offering allows contextual updates' do
            let(:service_offering) { VCAP::CloudController::Service.make(allow_context_updates: true) }

            it 'fails with a plan inaccessible message' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(422)
              expect(parsed_response['errors']).to include(
                include({
                  'detail' => 'Cannot update name of a service instance that belongs to inaccessible plan',
                  'title' => 'CF-UnprocessableEntity',
                  'code' => 10008,
                })
              )
            end
          end

          context 'but the service offering does not allow contextual updates' do
            let(:service_offering) { VCAP::CloudController::Service.make(allow_context_updates: false) }

            it 'succeeds' do
              api_call.call(admin_headers)
              expect(last_response).to have_status_code(200)
            end
          end
        end
      end
    end

    context 'user-provided service instance' do
      let!(:service_instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(
          space: space,
          name: 'foo',
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          syslog_drain_url: 'https://foo.com',
          route_service_url: 'https://bar.com',
          tags: %w(accounting mongodb)
        )
        si.annotation_ids = [
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
        ]
        si.label_ids = [
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        ]
        si
      end

      let(:guid) { service_instance.guid }
      let(:new_name) { 'my_service_instance' }

      let(:request_body) do
        {
          name: new_name,
          credentials: {
            used_in: 'bindings',
            foo: 'bar',
          },
          syslog_drain_url: 'https://foo2.com',
          route_service_url: 'https://bar2.com',
          tags: %w(accounting couchbase nosql),
          metadata: {
            labels: {
              foo: 'bar',
              'pre.fix/to_delete': nil,
            },
            annotations: {
              alpha: 'beta',
              'pre.fix/to_delete': nil,
            }
          }
        }
      end

      it 'allows updates' do
        api_call.call(space_dev_headers)
        expect(last_response).to have_status_code(200)

        expect(parsed_response).to match_json_response(
          create_user_provided_json(
            service_instance.reload,
            labels: {
              foo: 'bar',
              'pre.fix/tail': 'fluffy'
            },
            annotations: {
              alpha: 'beta',
              'pre.fix/fox': 'bushy'
            },
            last_operation: {
              type: 'update',
              state: 'succeeded',
              description: 'Operation succeeded',
              created_at: iso8601,
              updated_at: iso8601,
            }
          )
        )
      end

      it 'updates the a service instance in the database' do
        api_call.call(space_dev_headers)

        instance = VCAP::CloudController::ServiceInstance.last

        expect(instance.name).to eq(new_name)
        expect(instance.syslog_drain_url).to eq('https://foo2.com')
        expect(instance.route_service_url).to eq('https://bar2.com')
        expect(instance.tags).to contain_exactly('accounting', 'couchbase', 'nosql')
        expect(instance.space).to eq(space)
        expect(instance.last_operation.type).to eq('update')
        expect(instance.last_operation.state).to eq('succeeded')
        expect(instance).to have_labels({ prefix: 'pre.fix', key: 'tail', value: 'fluffy' }, { prefix: nil, key: 'foo', value: 'bar' })
        expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'fox', value: 'bushy' }, { prefix: nil, key: 'alpha', value: 'beta' })
      end

      context 'when the request is invalid' do
        let(:request_body) do
          {
            guid: Sham.guid
          }
        end

        it 'is rejected' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => include("Unknown field(s): 'guid'"),
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end

      context 'when the name is already taken' do
        let!(:duplicate_name) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, name: new_name) }

        let(:request_body) do
          {
            name: new_name
          }
        end

        it 'is rejected' do
          api_call.call(space_dev_headers)
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(
            include({
              'detail' => "The service instance name is taken: #{new_name}.",
              'title' => 'CF-UnprocessableEntity',
              'code' => 10008,
            })
          )
        end
      end
    end

    context 'when an operation is in progress' do
      let(:service_instance) {
        si = VCAP::CloudController::ManagedServiceInstance.make(
          space: space
        )
        si.save_with_new_operation({}, { type: 'create', state: 'in progress', description: 'almost there, I promise' })
        si
      }
      let(:guid) { service_instance.guid }
      let(:request_body) {
        {
          metadata: {
            labels: { unit: 'metre', distance: '1003' },
            annotations: { location: 'london' }
          }
        }
      }

      context 'and the update contains metadata only' do
        it 'updates the metadata' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(200)
          expect(parsed_response.dig('metadata', 'labels')).to eq({ 'unit' => 'metre', 'distance' => '1003' })
          expect(parsed_response.dig('metadata', 'annotations')).to eq({ 'location' => 'london' })
        end

        it 'does not update the service instance last operation' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(200)
          expect(parsed_response['last_operation']).to include({
            'type' => 'create',
            'state' => 'in progress',
            'description' => 'almost there, I promise'
          })
        end
      end

      context 'and the update contains more than just metadata' do
        it 'returns an error' do
          request_body[:name] = 'new-name'
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(409)
          response = parsed_response['errors'].first
          expect(response).to include('title' => 'CF-AsyncServiceInstanceOperationInProgress')
          expect(response).to include('detail' => include("An operation for service instance #{service_instance.name} is in progress"))
        end
      end
    end
  end

  describe 'DELETE /v3/service_instances/:guid' do
    let(:query_params) { '' }
    let(:api_call) { lambda { |user_headers| delete "/v3/service_instances/#{instance.guid}?#{query_params}", '{}', user_headers } }

    context 'permissions' do
      let!(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }
      let(:db_check) {
        lambda {
          expect(VCAP::CloudController::ServiceInstance.all).to be_empty
        }
      }

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_delete_endpoint }
      end

      it_behaves_like 'permissions for delete endpoint when organization is suspended', 204 do
        let(:expected_codes) {}
      end
    end

    context 'user provided service instances' do
      let!(:instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: 'https://banana.example.com/')
        si.service_instance_operation = VCAP::CloudController::ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
        si
      end
      let(:instance_labels) { VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: instance) }
      let(:instance_annotations) { VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: instance) }

      before do
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'banana', service_instance: instance)
        VCAP::CloudController::ServiceInstanceLabelModel.make(key_name: 'fruit', value: 'avocado', service_instance: instance)
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'contact', value: 'marie', service_instance: instance)
        VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'email', value: 'some@example.com', service_instance: instance)
      end

      it 'deletes the instance and removes any labels or annotations' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(204)

        get "/v3/service_instances/#{instance.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)
        expect(VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: instance).all).to be_empty
        expect(VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: instance).all).to be_empty
      end

      it 'deletes any related bindings' do
        VCAP::CloudController::RouteBinding.make(service_instance: instance)
        VCAP::CloudController::ServiceBinding.make(service_instance: instance)

        api_call.call(admin_headers)
        expect(last_response).to have_status_code(204)

        expect(VCAP::CloudController::ServiceInstance.all).to be_empty
        expect(VCAP::CloudController::RouteBinding.all).to be_empty
        expect(VCAP::CloudController::ServiceBinding.all).to be_empty
      end

      context 'with purge' do
        let(:query_params) { 'purge=true' }
        before(:each) do
          @binding = VCAP::CloudController::ServiceBinding.make(service_instance: instance)
          @route = VCAP::CloudController::RouteBinding.make(service_instance: instance)
        end

        it 'deletes the instance and the related resources' do
          api_call.call(admin_headers)
          expect(last_response).to have_status_code(204)

          expect { instance.reload }.to raise_error Sequel::NoExistingObject
          expect { @binding.reload }.to raise_error Sequel::NoExistingObject
          expect { @route.reload }.to raise_error Sequel::NoExistingObject
          expect(instance_labels.count).to eq(0)
          expect(instance_annotations.count).to eq(0)
        end
      end
    end

    context 'managed service instance' do
      let!(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:broker_status_code) { 200 }
      let(:broker_response) { {} }
      let!(:stub_delete) {
        stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
          with(query: {
            'accepts_incomplete' => true,
            'service_id' => instance.service.broker_provided_id,
            'plan_id' => instance.service_plan.broker_provided_id
          }).
          to_return(status: broker_status_code, body: broker_response.to_json, headers: {})
      }

      it 'responds with job resource' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(202)

        job = VCAP::CloudController::PollableJobModel.last
        expect(last_response.headers['Location']).to end_with("/v3/jobs/#{job.guid}")

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
        expect(job.operation).to eq('service_instance.delete')
        expect(job.resource_guid).to eq(instance.guid)
        expect(job.resource_type).to eq('service_instance')
      end

      describe 'the pollable job' do
        it 'sends a delete request with the right arguments to the service broker' do
          api_call.call(headers_for(user, scopes: %w(cloud_controller.admin)))

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
          expect(
            a_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}").
              with(
                query: {
                  accepts_incomplete: true,
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                },
                headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
              )
          ).to have_been_made.once
        end

        context 'when the service broker responds synchronously' do
          context 'with success' do
            it 'removes the service instance' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end

            it 'completes the job' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              job = VCAP::CloudController::PollableJobModel.last
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end
          end

          context 'with an error' do
            let(:broker_status_code) { 404 }

            it 'marks the service instance as delete failed' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)
              instance.reload

              expect(instance.last_operation).to_not be_nil
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
            end

            it 'completes with failure' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              job = VCAP::CloudController::PollableJobModel.last
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end
          end
        end

        context 'when the service broker responds asynchronously' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'some delete operation' } }
          let(:last_operation_response) { { state: 'in progress', description: 'deleting si' } }
          let(:last_operation_status_code) { 200 }
          let(:job) { VCAP::CloudController::PollableJobModel.last }

          before do
            stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
              with(
                query: {
                  operation: 'some delete operation',
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                }).
              to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
          end

          it 'marks the job state as polling' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
          end

          it 'calls last operation immediately' do
            api_call.call(headers_for(user, scopes: %w(cloud_controller.admin)))
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            encoded_user_guid = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")
            expect(
              a_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  },
                  headers: { 'X-Broker-Api-Originating-Identity' => "cloudfoundry #{encoded_user_guid}" },
                )
            ).to have_been_made.once
          end

          it 'enqueues the next fetch last operation job' do
            api_call.call(admin_headers)

            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            expect(Delayed::Job.count).to eq(1)
          end

          it 'sets the service instance last operation to delete in progress' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            instance.reload

            expect(instance.last_operation).to_not be_nil
            expect(instance.last_operation.type).to eq('delete')
            expect(instance.last_operation.state).to eq('in progress')
          end

          context 'when last operation eventually returns `delete succeeded`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 200, body: { state: 'succeeded' }.to_json, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'removes the service instance last from the db' do
              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end
          end

          context 'when last operation eventually returns `delete failed`' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(3).then.
                to_return(status: 200, body: { state: 'failed', description: 'oh no failed' }.to_json, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              (1..2).each do |attempt|
                Timecop.freeze(Time.now + attempt.hour) do
                  execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)
                end
              end
              Timecop.freeze(Time.now + 3.hour) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to delete failed' do
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
              expect(instance.last_operation.description).to eq('oh no failed')
            end
          end

          context 'when last operation eventually returns 410 Gone' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 410, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'completes the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
            end

            it 'removes the service instance last from the db' do
              expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
            end
          end

          context 'when last operation eventually returns 400 Bad Request' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 400, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 0, expected_failures: 1)
              end
            end

            it 'fails the job' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
            end

            it 'sets the service instance last operation to delete failed' do
              expect(instance.last_operation.type).to eq('delete')
              expect(instance.last_operation.state).to eq('failed')
            end
          end

          context 'when last operation returns with an unknown status code' do
            before do
              stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
                with(
                  query: {
                    operation: 'some delete operation',
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  }).
                to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {}).times(1).then.
                to_return(status: 404, headers: {})

              api_call.call(admin_headers)

              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)

              Timecop.freeze(Time.now + 1.hour) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            it 'continues to poll' do
              updated_job = VCAP::CloudController::PollableJobModel.find(guid: job.guid)
              expect(updated_job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
            end
          end
        end

        context 'when the service instance is shared' do
          let!(:shared_space) do
            VCAP::CloudController::Space.make.tap do |s|
              instance.add_shared_space(s)
            end
          end

          it 'removes the service instance' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(VCAP::CloudController::ServiceInstance.all).to be_empty
          end

          context 'when there is a binding in the shared space' do
            let!(:application) { VCAP::CloudController::AppModel.make(space: shared_space) }
            let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, app: application) }

            before do
              stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{service_binding.guid}").
                with(query: {
                  'accepts_incomplete' => true,
                  'service_id' => instance.service.broker_provided_id,
                  'plan_id' => instance.service_plan.broker_provided_id
                }).
                to_return(status: 202, body: '{}', headers: {})
            end

            it 'fails when the unbind is async' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)

              lo = instance.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('failed')
              expect(lo.description).to eq("An operation for the service binding between app #{application.name} and service instance #{instance.name} is in progress.")

              expect(
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{service_binding.guid}").
                  with(query: {
                    'accepts_incomplete' => true,
                    service_id: instance.service.broker_provided_id,
                    plan_id: instance.service_plan.broker_provided_id
                  })
              ).to have_been_made.once
            end
          end
        end

        context 'when there are bindings' do
          let(:service_offering) { VCAP::CloudController::Service.make(requires: %w(route_forwarding)) }
          let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
          let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
          let!(:route_binding) { VCAP::CloudController::RouteBinding.make(service_instance: instance) }
          let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance) }
          let!(:service_key) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }

          context 'and the broker responds synchronously to the bindings being deleted' do
            before do
              [route_binding, service_binding, service_key].each do |binding|
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                  with(query: {
                    'accepts_incomplete' => true,
                    'service_id' => instance.service.broker_provided_id,
                    'plan_id' => instance.service_plan.broker_provided_id
                  }).
                  to_return(status: 200, body: '{}', headers: {})
              end
            end

            it 'removes the service instance' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(VCAP::CloudController::ServiceInstance.all).to be_empty
              expect(VCAP::CloudController::RouteBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceKey.all).to be_empty

              [route_binding, service_binding, service_key].each do |binding|
                expect(
                  a_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                    with(query: {
                      accepts_incomplete: true,
                      service_id: instance.service.broker_provided_id,
                      plan_id: instance.service_plan.broker_provided_id
                    })
                ).to have_been_made.once
              end
            end
          end

          context 'and the broker responds asynchronously to the bindings being deleted' do
            before do
              [route_binding, service_binding, service_key].each do |binding|
                stub_request(:delete, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}").
                  with(query: {
                    'accepts_incomplete' => true,
                    'service_id' => instance.service.broker_provided_id,
                    'plan_id' => instance.service_plan.broker_provided_id
                  }).
                  to_return(status: 202, body: '{}', headers: {})

                stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}/last_operation").
                  with(query: {
                    'service_id' => instance.service.broker_provided_id,
                    'plan_id' => instance.service_plan.broker_provided_id
                  }).
                  to_return(status: 200, body: '{"state":"succeeded"}', headers: {})
              end
            end

            it 'fails and starts the delete operation on the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)

              lo = VCAP::CloudController::ServiceInstance.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('failed')
              expect(lo.description).to eq("An operation for a service binding of service instance #{instance.name} is in progress.")

              lo = VCAP::CloudController::RouteBinding.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')

              lo = VCAP::CloudController::ServiceBinding.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')

              lo = VCAP::CloudController::ServiceKey.first.last_operation
              expect(lo.type).to eq('delete')
              expect(lo.state).to eq('in progress')
            end

            it 'continues to poll the last operation for the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 3, expected_failures: 1)

              [route_binding, service_binding, service_key].each do |binding|
                expect(
                  stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/service_bindings/#{binding.guid}/last_operation").
                    with(query: {
                      service_id: instance.service.broker_provided_id,
                      plan_id: instance.service_plan.broker_provided_id
                    })
                ).to have_been_made.once
              end
            end

            it 'eventually removes the bindings' do
              api_call.call(admin_headers)
              execute_all_jobs(expected_successes: 3, expected_failures: 1)

              expect(VCAP::CloudController::RouteBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceBinding.all).to be_empty
              expect(VCAP::CloudController::ServiceKey.all).to be_empty
            end
          end
        end
      end

      context 'when purge is true' do
        let(:query_params) { 'purge=true' }
        let(:service_offering) { VCAP::CloudController::Service.make(requires: %w(route_forwarding)) }
        let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan) }
        before(:each) do
          @binding = VCAP::CloudController::ServiceBinding.make(service_instance: instance)
          @key = VCAP::CloudController::ServiceKey.make(service_instance: instance)
          @route = VCAP::CloudController::RouteBinding.make(service_instance: instance)

          api_call.call(admin_headers)
        end

        it 'removes all associations' do
          expect { @binding.reload }.to raise_error Sequel::NoExistingObject
          expect { @key.reload }.to raise_error Sequel::NoExistingObject
          expect { @route.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'deletes the service instance' do
          expect { instance.reload }.to raise_error Sequel::NoExistingObject
        end

        it 'responds with 204' do
          expect(last_response).to have_status_code(204)
        end
      end

      context 'when delete is already in progress' do
        before do
          instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
        end

        it 'responds with 422' do
          api_call.call(admin_headers)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors']).to include(include({
            'detail' => include('There is an operation in progress for the service instance.'),
            'title' => 'CF-UnprocessableEntity',
            'code' => 10008,
          }))
        end
      end

      context 'when the creation is still in progress' do
        before do
          instance.save_with_new_operation({}, {
            type: 'create',
            state: 'in progress',
            broker_provided_operation: 'some create operation'
          })
        end

        context 'and the broker confirms the deletion' do
          it 'deletes the service instance' do
            api_call.call(admin_headers)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(VCAP::CloudController::ServiceInstance.first(guid: instance.guid)).to be_nil
          end
        end

        context 'and the broker accepts the delete' do
          let(:broker_status_code) { 202 }
          let(:broker_response) { { operation: 'some delete operation' } }
          let(:last_operation_response) { { state: 'in progress', description: 'deleting si' } }
          let(:last_operation_status_code) { 200 }

          before do
            stub_request(:get, "#{instance.service_broker.broker_url}/v2/service_instances/#{instance.guid}/last_operation").
              with(
                query: {
                  operation: 'some delete operation',
                  service_id: instance.service.broker_provided_id,
                  plan_id: instance.service_plan.broker_provided_id
                }).
              to_return(status: last_operation_status_code, body: last_operation_response.to_json, headers: {})
          end

          it 'triggers the delete process' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            instance.reload

            expect(instance.last_operation).to_not be_nil
            expect(instance.last_operation.type).to eq('delete')
            expect(instance.last_operation.state).to eq('in progress')
            expect(instance.last_operation.broker_provided_operation).to eq('some delete operation')
          end
        end

        context 'but the broker rejects the delete' do
          let(:broker_status_code) { 422 }
          let(:broker_response) { { error: 'ConcurrencyError', description: 'Cannot delete right now' } }

          it 'responds with an error' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            job = VCAP::CloudController::PollableJobModel.last
            expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)

            expect(job.cf_api_error).to_not be_nil
            api_error = YAML.safe_load(job.cf_api_error)['errors'].first
            expect(api_error['title']).to eql('CF-AsyncServiceInstanceOperationInProgress')
            expect(api_error['detail']).to eql("An operation for service instance #{instance.name} is in progress.")
          end

          it 'does not change the operation in progress' do
            api_call.call(admin_headers)
            expect(last_response).to have_status_code(HTTP::Status::ACCEPTED)
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            instance.reload

            expect("#{instance.last_operation.type} #{instance.last_operation.state}").to eq('create in progress')
            expect(instance.last_operation.broker_provided_operation).to eq('some create operation')
          end
        end
      end
    end

    context 'when the service instance does not exist' do
      let(:instance) { Struct.new(:guid).new('some-fake-guid') }
      it 'returns a 404' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(404)
      end
    end
  end

  describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
    let(:api_call) { lambda { |user_headers| post "/v3/service_instances/#{guid}/relationships/shared_spaces", request_body.to_json, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:request_body) do
      {
        'data' => [
          { 'guid' => target_space_1.guid },
          { 'guid' => target_space_2.guid }
        ]
      }
    end
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:guid) { service_instance.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
    end

    describe 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_update_endpoint(success_code: 200) }
      end

      context 'sharing to a suspended org' do
        let(:target_space_1) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.organization.status = VCAP::CloudController::Organization::SUSPENDED
          space.organization.save
          space
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            responses_for_org_suspended_space_restricted_update_endpoint(success_code: 200).merge({ 'space_developer' => { code: 422 } })
          end
        end
      end
    end

    it 'shares the service instance to the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.service_instance.share',
        actor: user.guid,
        actee_type: 'service_instance',
        actee_name: service_instance.name,
        space_guid: space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guids']).to include(target_space_1.guid, target_space_2.guid)

      service_instance.reload
      expect(service_instance.shared_spaces).to include(target_space_1, target_space_2)
    end

    describe 'when service_instance_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to share services' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: service_instance_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330002,
            })
        )
      end
    end

    it 'responds with 404 when the instance does not exist' do
      post '/v3/service_instances/some-fake-guid/relationships/shared_spaces', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Service instance not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end

    describe 'when the request body is invalid' do
      context 'when it is not a valid relationship' do
        let(:request_body) do
          {
            'data' => { 'guid' => target_space_1.guid }
          }
        end

        it 'should respond with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'Data must be an array',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'when there are additional keys' do
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_1.guid }
            ],
            'fake-key' => 'foo'
          }
        end

        it 'should respond with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unknown field(s): 'fake-key'",
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end

    describe 'target space to share to' do
      context 'does not exist' do
        let(:target_space_guid) { 'fake-target' }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_guid }
            ]
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share service instance #{service_instance.name} with spaces ['#{target_space_guid}']. " \
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'user does not have access to one of the target spaces' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => no_access_target_space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the instance' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share service instance #{service_instance.name} with spaces ['#{no_access_target_space.guid}']. "\
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              })
          )

          service_instance.reload
          expect(service_instance.shared?).to be_falsey
        end
      end
    end

    describe 'errors while sharing' do
      context 'service instance is user provided' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space) }

        it 'should respond with 422 and the error' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'User-provided services cannot be shared.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end
  end

  describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space_guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/service_instances/#{guid}/relationships/shared_spaces/#{space_guid}", nil, user_headers } }
    let(:target_space) { VCAP::CloudController::Space.make(organization: org) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:guid) { service_instance.guid }
    let(:space_guid) { target_space.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    before do
      share_service_instance(service_instance, target_space)
    end

    describe 'permissions' do
      let(:db_check) {
        lambda {
          si = VCAP::CloudController::ServiceInstance.first(guid: guid)
          expect(si.shared?).to be_falsey
        }
      }

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_delete_endpoint }
      end

      it_behaves_like 'permissions for delete endpoint when organization is suspended', ALL_PERMISSIONS do
        let(:expected_codes) { responses_for_org_suspended_space_restricted_delete_endpoint(success_code: 204) }
      end
    end

    it 'unshares the service instance from the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.service_instance.unshare',
        actor: user.guid,
        actee_type: 'service_instance',
        actee_name: service_instance.name,
        space_guid: space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)
    end

    describe 'when there are bindings in the shared space' do
      let(:app_1) { VCAP::CloudController::AppModel.make(space: target_space) }
      let(:app_2) { VCAP::CloudController::AppModel.make(space: target_space) }

      let(:binding_1) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: app_1) }
      let(:binding_2) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: app_2) }

      context 'and the bindings can be deleted synchronously' do
        before do
          stub_unbind(binding_1, accepts_incomplete: true, status: 200, body: {}.to_json)
          stub_unbind(binding_2, accepts_incomplete: true, status: 200, body: {}.to_json)
        end

        it 'deletes all bindings and successfully unshares' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(204)

          service_instance.reload
          expect(service_instance.shared?).to be_falsey
          expect(service_instance.has_bindings?).to be_falsey
        end
      end

      context 'but the bindings can only be deleted asynchronously' do
        before do
          stub_unbind(binding_1, accepts_incomplete: true, status: 202, body: {}.to_json)
          stub_unbind(binding_2, accepts_incomplete: true, status: 200, body: {}.to_json)
        end

        it 'responds with 502 and does not unshare' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(502)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unshare of service instance failed: \n\nUnshare of service instance failed because one or more bindings could not be deleted.\n\n " \
                            "\tThe binding between an application and service instance #{service_instance.name} in space #{target_space.name} is being deleted asynchronously.",
                'title' => 'CF-ServiceInstanceUnshareFailed'
              })
          )

          expect(service_instance.shared?).to be_truthy
        end
      end
    end

    it 'responds with 404 when the instance does not exist' do
      delete "/v3/service_instances/some-fake-guid/relationships/shared_spaces/#{space_guid}",
        nil,
        space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Service instance not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end

    describe 'target space to unshare from' do
      context 'when it does not exist' do
        let(:space_guid) { 'fake-target' }

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare service instance from space #{space_guid}. " \
                      'Ensure the space exists.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'when instance was not shared to the space' do
        let(:space_guid) { VCAP::CloudController::Space.make(organization: org).guid }

        it 'responds with 204' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/relationships/shared_spaces' do
    let(:user_header) { headers_for(user) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:other_space) { VCAP::CloudController::Space.make }

    before(:each) do
      share_service_instance(instance, other_space)
    end

    describe 'permissions in originating space' do
      let(:api_call) { lambda { |user_headers| get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", nil, user_headers } }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_response) do
          {
            data: [{ guid: other_space.guid }],
            links: {
              self: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces" },
            }
          }
        end

        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(expected_response)
        end
      end
    end

    it 'respond with 404 when the user cannot read the originating space' do
      set_current_user_as_role(role: 'space_developer', org: other_space.organization, space: other_space, user: user)
      get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", nil, user_header
      expect(last_response.status).to eq(404)
    end

    describe 'fields' do
      it 'can include the space name, guid and organization relationship fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space]=name,guid,relationships.organization", nil, admin_headers
        expect(last_response).to have_status_code(200)

        r = { organization: { data: { guid: other_space.organization.guid } } }
        included = {
          spaces: [
            { name: other_space.name, guid: other_space.guid, relationships: r }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end

      it 'can include the organization name and guid fields through space' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space.organization]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          organizations: [
            {
              name: other_space.organization.name,
              guid: other_space.organization.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: included })
      end

      it 'fails for invalid resources' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[fruit]=name", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields [fruit] valid resources are: 'space', 'space.organization'"
          )
        )
      end

      it 'fails for not allowed space fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space]=metadata", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields valid keys for 'space' are: 'name', 'guid', 'relationships.organization'"
          )
        )
      end

      it 'fails for not allowed space.organization fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space.organization]=metadata", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields valid keys for 'space.organization' are: 'name', 'guid'"
          )
        )
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/relationships/shared_spaces/usage_summary' do
    let(:guid) { instance.guid }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:space_1) { VCAP::CloudController::Space.make }
    let(:space_2) { VCAP::CloudController::Space.make }
    let(:space_3) { VCAP::CloudController::Space.make }
    let(:url) { "/v3/service_instances/#{guid}/relationships/shared_spaces/usage_summary" }
    let(:api_call) { lambda { |user_headers| get url, nil, user_headers } }
    let(:bindings_on_space_1) { 1 }
    let(:bindings_on_space_2) { 3 }

    def create_bindings(instance, space:, count:)
      (1..count).each do
        VCAP::CloudController::ServiceBinding.make(
          app: VCAP::CloudController::AppModel.make(space: space),
          service_instance: instance
        )
      end
    end

    before do
      share_service_instance(instance, space_1)
      share_service_instance(instance, space_2)
      share_service_instance(instance, space_3)

      create_bindings(instance, space: space_1, count: bindings_on_space_1)
      create_bindings(instance, space: space_2, count: bindings_on_space_2)
    end

    context 'permissions' do
      let(:response_object) {
        {
          usage_summary: [
            { space: { guid: space_1.guid }, bound_app_count: bindings_on_space_1 },
            { space: { guid: space_2.guid }, bound_app_count: bindings_on_space_2 },
            { space: { guid: space_3.guid }, bound_app_count: 0 }
          ],
          links: {
            self: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces/usage_summary" },
            shared_spaces: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces" },
            service_instance: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}" }
          }
        }
      }

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(response_object)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the instance does not exist' do
      let(:guid) { 'a-fake-guid' }
      it 'responds with 404 Not Found' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the user cannot read from the originating space' do
      it 'responds with 404 Not Found' do
        user = VCAP::CloudController::User.make
        set_current_user_as_role(role: 'space_developer', org: space_2.organization, space: space_2, user: user)

        api_call.call(headers_for(user))

        expect(last_response).to have_status_code(404)
      end
    end
  end

  def create_managed_json(instance, labels: {}, annotations: {}, last_operation: {}, tags: [])
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'managed',
      dashboard_url: nil,
      last_operation: last_operation,
      maintenance_info: {},
      upgrade_available: false,
      tags: tags,
      metadata: {
        labels: labels,
        annotations: annotations,
      },
      relationships: {
        space: {
          data: {
            guid: instance.space.guid
          }
        },
        service_plan: {
          data: {
            guid: instance.service_plan.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        service_plan: {
          href: "#{link_prefix}/v3/service_plans/#{instance.service_plan.guid}"
        },
        parameters: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/parameters"
        },
        service_credential_bindings: {
          href: "#{link_prefix}/v3/service_credential_bindings?service_instance_guids=#{instance.guid}"
        },
        service_route_bindings: {
          href: "#{link_prefix}/v3/service_route_bindings?service_instance_guids=#{instance.guid}"
        },
        shared_spaces: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces"
        },
      },
    }
  end

  def create_user_provided_json(instance, labels: {}, annotations: {}, last_operation: {})
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'user-provided',
      last_operation: last_operation,
      syslog_drain_url: instance.syslog_drain_url,
      route_service_url: instance.route_service_url,
      tags: instance.tags,
      metadata: {
        labels: labels,
        annotations: annotations,
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
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        credentials: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/credentials"
        },
        service_credential_bindings: {
          href: "#{link_prefix}/v3/service_credential_bindings?service_instance_guids=#{instance.guid}"
        },
        service_route_bindings: {
          href: "#{link_prefix}/v3/service_route_bindings?service_instance_guids=#{instance.guid}"
        }
      },
    }
  end

  def share_service_instance(instance, target_space)
    enable_sharing!

    share_request = {
      'data' => [
        { 'guid' => target_space.guid }
      ]
    }

    post "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", share_request.to_json, admin_headers
    expect(last_response.status).to eq(200)
  end

  def enable_sharing!
    VCAP::CloudController::FeatureFlag.
      find_or_create(name: 'service_instance_sharing') { |ff| ff.enabled = true }.
      update(enabled: true)
  end
end
