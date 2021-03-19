require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Client do
    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

    let(:client_attrs) {
      {
        url: service_broker.broker_url,
        auth_username: service_broker.auth_username,
        auth_password: service_broker.auth_password,
      }
    }

    subject(:client) { Client.new(client_attrs) }

    let(:http_client) { instance_double(HttpClient) }
    let(:orphan_mitigator) { instance_double(OrphanMitigator, cleanup_failed_provision: nil, cleanup_failed_bind: nil, cleanup_failed_key: nil) }

    before do
      allow(HttpClient).to receive(:new).
        with(url: service_broker.broker_url, auth_username: service_broker.auth_username, auth_password: service_broker.auth_password).
        and_return(http_client)

      allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).
        and_return(orphan_mitigator)

      allow(http_client).to receive(:url).and_return(service_broker.broker_url)
    end

    describe '#initialize' do
      it 'creates HttpClient with correct attrs' do
        Client.new(client_attrs.merge(extra_arg: 'foo'))

        expect(HttpClient).to have_received(:new).with(client_attrs)
      end
    end

    describe '#catalog' do
      let(:service_id) { Sham.guid }
      let(:service_name) { Sham.name }
      let(:service_description) { Sham.description }
      let(:plan_id) { Sham.guid }
      let(:plan_name) { Sham.name }
      let(:plan_description) { Sham.description }

      let(:response_data) do
        {
          'services' => [
            {
              'id' => service_id,
              'name' => service_name,
              'description' => service_description,
              'plans' => [
                {
                  'id' => plan_id,
                  'name' => plan_name,
                  'description' => plan_description
                }
              ]
            }
          ]
        }
      end

      let(:path) { '/v2/catalog' }
      let(:catalog_response) { HttpResponse.new(code: code, body: catalog_response_body, message: message) }
      let(:catalog_response_body) { response_data.to_json }
      let(:code) { 200 }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:get).and_return(catalog_response)
      end

      it 'returns a catalog' do
        expect(client.catalog).to eq(response_data)
        expect(http_client).to have_received(:get).with(path, { user_guid: nil })
      end

      context 'with a user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.catalog(user_guid: user_guid)
          expect(http_client).to have_received(:get).with(anything, { user_guid: user_guid })
        end
      end
    end

    describe '#provision' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance_operation) { VCAP::CloudController::ServiceInstanceOperation.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: plan,
          space: space,
          name: 'instance-007'
        )
      end

      let(:response_data) do
        {
          'dashboard_url' => 'foo'
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, body: response_body, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { 201 }
      let(:message) { 'Created' }
      let(:developer) { make_developer_for_space(instance.space) }

      before do
        allow(http_client).to receive(:put).and_return(response)
        allow(http_client).to receive(:delete).and_return(response)
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(developer)

        instance.service_instance_operation = service_instance_operation
      end

      it 'makes a put request with correct path' do
        client.provision(instance)

        expect(http_client).to have_received(:put).
          with(path, anything, { user_guid: nil })
      end

      context 'when the caller passes the accepts_incomplete flag' do
        let(:path) { "/v2/service_instances/#{instance.guid}?accepts_incomplete=true" }

        it 'adds the flag to the path of the service broker request' do
          client.provision(instance, accepts_incomplete: true)

          expect(http_client).to have_received(:put).
            with(path, anything, { user_guid: nil })
        end
      end

      it 'makes a put request with correct message' do
        client.provision(instance)

        expect(http_client).to have_received(:put).with(
          anything,
          {
            service_id: instance.service.broker_provided_id,
            plan_id: instance.service_plan.broker_provided_id,
            organization_guid: instance.organization.guid,
            space_guid: instance.space.guid,
            context: {
              platform: 'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid: instance.space_guid,
              instance_name: instance.name,
              instance_annotations: {},
              organization_name: instance.organization.name,
              space_name: instance.space.name,
              organization_annotations: {},
              space_annotations: {}
            }
          },
          { user_guid: nil }
        )
      end

      context 'when annotations are set' do
        let!(:private_org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_name: 'foo', value: 'bar', resource_guid: instance.organization.guid) }
        let!(:public_org_annotation) {
          VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: instance.organization.guid)
        }
        let!(:private_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'bar', value: 'wow', space: instance.space) }
        let!(:public_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'bar', value: 'wow', space: instance.space) }
        let!(:public_legacy_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'pre.fix/wow', value: 'bar', space: instance.space) }
        let!(:private_instance_annotation) { VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_name: 'baz', value: 'wow', service_instance: instance) }
        let!(:public_instance_annotation) {
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'baz', value: 'wow', service_instance: instance)
        }

        it 'sends the annotations in the context' do
          client.provision(instance)

          expect(http_client).to have_received(:put).with(
            anything,
            hash_including(
              context: {
                platform: 'cloudfoundry',
                organization_guid: instance.organization.guid,
                space_guid: instance.space_guid,
                instance_name: instance.name,
                instance_annotations: { 'pre.fix/baz' => 'wow' },
                organization_name: instance.organization.name,
                space_name: instance.space.name,
                organization_annotations: { 'pre.fix/foo' => 'bar' },
                space_annotations: { 'pre.fix/bar' => 'wow', 'pre.fix/wow' => 'bar' }
              }),
            { user_guid: nil }
          )
        end
      end

      describe 'return values' do
        let(:response_data) do
          {
            dashboard_url: 'http://example-dashboard.com/9189kdfsk0vfnku'
          }
        end

        attributes = nil
        before do
          attributes = client.provision(instance)
        end

        it 'DEPRCATED: returns an empty credentials hash to satisfy the not null database constraint' do
          expect(attributes[:instance][:credentials]).to eq({})
        end

        it 'returns the dashboard url' do
          expect(attributes[:instance][:dashboard_url]).to eq('http://example-dashboard.com/9189kdfsk0vfnku')
        end

        describe 'last operation' do
          it 'defaults the state to "succeeded"' do
            expect(attributes[:last_operation][:state]).to eq('succeeded')
          end

          it 'leaves the description blank' do
            expect(attributes[:last_operation][:description]).to eq('')
          end
        end
      end

      it 'passes arbitrary params in the broker request' do
        arbitrary_parameters = {
          'some_param' => 'some-value'
        }

        client.provision(instance, arbitrary_parameters: arbitrary_parameters)
        expect(http_client).to have_received(:put).with(path, hash_including(parameters: arbitrary_parameters), { user_guid: nil })
      end

      it 'passes the maintenance_info to the broker' do
        client.provision(instance, maintenance_info: { version: '2.0.0' })
        expect(http_client).to have_received(:put).with(path, hash_including(maintenance_info: { version: '2.0.0' }), { user_guid: nil })
      end

      context 'when the caller passes the user_guid flag' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.provision(instance, user_guid: user_guid)
          expect(http_client).to have_received(:put).with(path, anything, { user_guid: user_guid })
        end
      end

      context 'when the broker returns 204 (No Content)' do
        let(:code) { 204 }
        let(:client) { Client.new(client_attrs) }

        it 'raises ServiceBrokerBadResponse and initiates orphan mitigation' do
          expect {
            client.provision(instance)
          }.to raise_error(Errors::ServiceBrokerBadResponse)

          expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(instance)
        end
      end

      context 'when the broker returns a operation' do
        let(:response_data) do
          { operation: 'a_broker_operation_identifier' }
        end

        context 'and the response is a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }

          it 'return immediately with the operation from the broker response' do
            client = Client.new(client_attrs)
            attributes, _ = client.provision(instance, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client = Client.new(client_attrs)
            attributes, _ = client.provision(instance, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to be_nil
          end
        end
      end

      context 'when the broker returns a 202' do
        let(:code) { 202 }
        let(:message) { 'Accepted' }
        let(:response_data) do
          {}
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs)
          attributes, _ = client.provision(instance, accepts_incomplete: true)

          expect(attributes[:instance][:broker_provided_operation]).to be_nil
          expect(attributes[:last_operation][:type]).to eq('create')
          expect(attributes[:last_operation][:state]).to eq('in progress')
        end
      end

      context 'when the broker returns the state as failed' do
        let(:code) { 400 }
        let(:message) { 'Failed' }
        let(:response_data) do
          {}
        end

        it 'raises an error' do
          client = Client.new(client_attrs)
          expect { client.provision(instance, accepts_incomplete: true) }.to raise_error(Errors::ServiceBrokerRequestRejected)
        end
      end

      context 'when provision fails' do
        let(:uri) { 'some-uri.com/v2/service_instances/some-guid' }
        let(:response) { HttpResponse.new(code: nil, body: nil, message: nil) }

        context 'due to an http client error' do
          let(:http_client) { instance_double(HttpClient) }

          before do
            allow(http_client).to receive(:put).and_raise(error)
          end

          context 'Errors::HttpClientTimeout error' do
            let(:error) { Errors::HttpClientTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::HttpClientTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(instance)
            end
          end
        end

        context 'due to a response parser error' do
          let(:response_parser) { instance_double(ResponseParser) }

          before do
            allow(response_parser).to receive(:parse_provision).and_raise(error)
            allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and does not follow up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).not_to have_received(:cleanup_failed_provision)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(instance)
            end
          end

          context 'ConcurrencyError error' do
            let(:error) { Errors::ConcurrencyError.new(uri, :put, response) }

            it 'propagates the error and does not issue a deprovision' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ConcurrencyError)

              expect(orphan_mitigator).not_to have_received(:cleanup_failed_provision)
            end
          end

          context 'ServiceBrokerResponseMalformed error' do
            let(:error) { Errors::ServiceBrokerResponseMalformed.new(uri, :put, response, '') }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(instance)
            end

            context 'when the status code was a 200' do
              let(:response) { HttpResponse.new(code: 200, body: nil, message: nil) }

              it 'does not initiate orphan mitigation' do
                expect {
                  client.provision(instance)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)

                expect(orphan_mitigator).not_to have_received(:cleanup_failed_provision).with(instance)
              end
            end
          end
        end
      end
    end

    describe '#fetch_service_instance_last_operation' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: plan,
          space: space
        )
      end

      let(:response_data) do
        {
          'state' => 'succeeded',
          'description' => '100% created'
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, message: message, body: response_body) }
      let(:response_body) { response_data.to_json }
      let(:code) { 200 }
      let(:message) { 'OK' }
      let(:broker_provided_operation) { nil }
      let(:operation_type) { 'create' }

      before do
        instance.save_with_new_operation({}, { type: operation_type, broker_provided_operation: broker_provided_operation })
        allow(http_client).to receive(:get).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.fetch_service_instance_last_operation(instance)

        expect(http_client).to have_received(:get).with(
          "/v2/service_instances/#{instance.guid}/last_operation?plan_id=#{plan.broker_provided_id}&service_id=#{instance.service.broker_provided_id}",
          { user_guid: nil }
        )
      end

      context 'when the broker operation id is specified' do
        let(:broker_provided_operation) { 'a_broker_provided_operation' }
        it 'makes a put request with correct path' do
          client.fetch_service_instance_last_operation(instance)

          expect(http_client).to have_received(:get) do |path|
            uri = URI.parse(path)
            expect(uri.host).to be nil
            expect(uri.path).to eq("/v2/service_instances/#{instance.guid}/last_operation")

            query_params = Rack::Utils.parse_nested_query(uri.query)
            expect(query_params['plan_id']).to eq(plan.broker_provided_id)
            expect(query_params['service_id']).to eq(instance.service.broker_provided_id)
            expect(query_params['operation']).to eq(broker_provided_operation)
          end
        end
      end

      context 'when the user_guid is specified' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.fetch_service_instance_last_operation(instance, user_guid: user_guid)
          expect(http_client).to have_received(:get).with(anything, { user_guid: user_guid })
        end
      end

      it 'returns the attributes to update the service instance model' do
        attrs = client.fetch_service_instance_last_operation(instance)
        expected_attrs = { last_operation: response_data.symbolize_keys }
        expect(attrs).to eq(expected_attrs)
      end

      context 'when the broker provides other fields' do
        let(:response_data) do
          {
            'state' => 'succeeded',
            'description' => '100% created',
            'foo' => 'bar'
          }
        end

        it 'passes through the extra fields' do
          attrs = client.fetch_service_instance_last_operation(instance)
          expect(attrs[:foo]).to eq 'bar'
          expect(attrs[:last_operation]).to eq({ state: 'succeeded', description: '100% created' })
        end
      end

      context 'when the broker returns 410 (gone)' do
        let(:code) { 410 }
        let(:message) { 'GONE' }
        let(:response_data) do
          {}
        end

        context 'when the last operation type is `delete`' do
          before do
            instance.save_with_new_operation({}, { type: 'delete' })
          end

          it 'returns attributes to indicate the service instance was deleted' do
            attrs = client.fetch_service_instance_last_operation(instance)
            expect(attrs).to include(
              last_operation: {
                state: 'succeeded'
              }
            )
          end
        end

        context 'with any other operation type' do
          before do
            instance.save_with_new_operation({}, { type: 'update' })
          end

          it 'returns attributes to indicate the service instance operation is in progress' do
            attrs = client.fetch_service_instance_last_operation(instance)
            expect(attrs).to include(
              last_operation: {
                state: 'in progress'
              }
            )
          end
        end
      end

      context 'when the broker returns 400 (bad request)' do
        let(:code) { 400 }
        let(:message) { 'Bad Request' }
        let(:response_data) { {} }

        it 'includes the http status code on the response' do
          attrs = client.fetch_service_instance_last_operation(instance)
          expect(attrs).to include(
            http_status_code: 400
          )
        end

        context 'when the response includes a description' do
          let(:response_data) do
            {
              error: 'Bad Request',
              description: 'The request is missing something important'
            }
          end

          it 'returns attributes to indicate the service operation failed' do
            attrs = client.fetch_service_instance_last_operation(instance)
            expect(attrs).to include(
              last_operation: {
                state: 'failed',
                description: 'The request is missing something important'
              }
            )
          end
        end

        context 'when the response has no description' do
          it 'returns attributes to indicate the service operation failed' do
            attrs = client.fetch_service_instance_last_operation(instance)
            expect(attrs).to include(
              last_operation: {
                state: 'failed',
                description: 'Bad request'
              }
            )
          end
        end
      end

      context 'when the broker does not provide a description' do
        let(:response_data) do
          {
            'state' => 'succeeded'
          }
        end

        it 'does not return a description field' do
          attrs = client.fetch_service_instance_last_operation(instance)
          expect(attrs).to eq({ last_operation: { state: 'succeeded' } })
        end
      end

      context 'when the broker returns headers' do
        let(:response) { HttpResponse.new(code: code, message: message, body: response_body, headers: { 'Retry-After' => 10 }) }

        it 'returns the retry after header in the result' do
          attrs = client.fetch_service_instance_last_operation(instance)
          expected_attrs = { retry_after: 10, last_operation: response_data.symbolize_keys }
          expect(attrs).to eq(expected_attrs)
        end
      end
    end

    describe '#update' do
      let(:old_plan) { VCAP::CloudController::ServicePlan.make }
      let(:new_plan) { VCAP::CloudController::ServicePlan.make }

      let(:space) { VCAP::CloudController::Space.make }
      let(:last_operation) do
        VCAP::CloudController::ServiceInstanceOperation.make(
          type: 'create',
          state: 'succeeded'
        )
      end

      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: old_plan,
          space: space,
          name: 'instance-007'
        )
      end

      let(:service_plan_guid) { new_plan.guid }

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:code) { 200 }
      let(:message) { 'OK' }
      let(:response_body) { response_data.to_json }
      let(:response_data) { {} }

      before do
        response = HttpResponse.new(code: code, body: response_body, message: message)
        allow(http_client).to receive(:patch).and_return(response)
        instance.service_instance_operation = last_operation
      end

      it 'makes a patch request with the service_id included in the body' do
        client.update(instance, new_plan, previous_values: { plan_id: '1234' })

        expect(http_client).to have_received(:patch).with(
          anything,
          hash_including({
            service_id: instance.service.broker_provided_id,
          }),
          { user_guid: nil }
        )
      end

      it 'makes a patch request with the correct context in the body' do
        client.update(instance, new_plan, previous_values: { plan_id: '1234' }, name: 'fake_name')

        expect(http_client).to have_received(:patch).with(
          anything,
          hash_including({
            context: {
              platform: 'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid: instance.space_guid,
              instance_name: 'fake_name',
              organization_name: instance.organization.name,
              space_name: instance.space.name,
              organization_annotations: {},
              space_annotations: {}
            }
          }),
          { user_guid: nil }
        )
      end

      it 'makes a patch request with the correct context in the body (default name)' do
        client.update(instance, new_plan, previous_values: { plan_id: '1234' })

        expect(http_client).to have_received(:patch).with(
          anything,
          hash_including({
            context: {
              platform: 'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid: instance.space_guid,
              instance_name: instance.name,
              organization_name: instance.organization.name,
              space_name: instance.space.name,
              organization_annotations: {},
              space_annotations: {}
            }
          }),
          { user_guid: nil }
        )
      end

      context 'when annotations are set' do
        let!(:public_org_annotation1) {
          VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: instance.organization.guid)
        }
        let!(:public_org_annotation2) {
          VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'bar', value: 'foo', resource_guid: instance.organization.guid)
        }
        let!(:private_org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_name: 'baz', value: 'wow', resource_guid: instance.organization.guid) }
        let!(:public_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'bar', value: 'wow', space: instance.space) }
        let!(:public_legacy_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'pre.fix/wow', value: 'bar', space: instance.space) }
        let!(:private_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'bar', value: 'wow', space: instance.space) }

        it 'sends the annotations in the context' do
          client.update(instance, new_plan, previous_values: { plan_id: '1234' })

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including(
              context: {
                platform: 'cloudfoundry',
                organization_guid: instance.organization.guid,
                space_guid: instance.space_guid,
                instance_name: instance.name,
                organization_name: instance.organization.name,
                space_name: instance.space.name,
                organization_annotations: { 'pre.fix/foo' => 'bar', 'pre.fix/bar' => 'foo' },
                space_annotations: { 'pre.fix/bar' => 'wow', 'pre.fix/wow' => 'bar' }
              }),
            { user_guid: nil }
          )
        end
      end

      it 'makes a patch request to the correct path' do
        client.update(instance, new_plan)
        expect(http_client).to have_received(:patch).with(path, anything, { user_guid: nil })
      end

      context 'when the caller passes a new service plan' do
        it 'makes a patch request with the new service plan' do
          client.update(instance, new_plan, previous_values: { plan_id: '1234' })

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including({
              plan_id: new_plan.broker_provided_id,
              previous_values: {
                plan_id: '1234'
              }
            }),
            { user_guid: nil }
          )
        end
      end

      context 'when the caller passes arbitrary parameters' do
        it 'includes the parameters in the request to the broker' do
          client.update(instance, old_plan, arbitrary_parameters: { myParam: 'some-value' })

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including({
              parameters: { myParam: 'some-value' },
              previous_values: {}
            }),
            { user_guid: nil }
          )
        end
      end

      context 'when the caller passes maintenance_info' do
        let(:maintenance_info) { { version: '2.0' } }

        it 'includes the maintenance_info in the request to the broker' do
          client.update(instance, old_plan, maintenance_info: maintenance_info)

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including({
              maintenance_info: { version: '2.0' },
              previous_values: {}
            }),
            { user_guid: nil }
          )
        end

        context 'when the broker responds asynchronously' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }
          let(:response_data) do
            {}
          end

          it 'returns maintenance_info as a proposed changed' do
            client = Client.new(client_attrs.merge(accepts_incomplete: true))
            attributes, _, _ = client.update(instance, old_plan, maintenance_info: maintenance_info, accepts_incomplete: true)

            expect(attributes[:last_operation][:proposed_changes]).to eq({ service_plan_guid: old_plan.guid, maintenance_info: maintenance_info })
          end
        end
      end

      context 'when the caller passes the accepts_incomplete flag' do
        let(:path) { "/v2/service_instances/#{instance.guid}?accepts_incomplete=true" }

        it 'adds the flag to the path of the service broker request' do
          client.update(instance, new_plan, accepts_incomplete: true)

          expect(http_client).to have_received(:patch).
            with(path, anything, { user_guid: nil })
        end

        context 'and the broker returns a 200' do
          let(:response_data) do
            {}
          end

          it 'marks the last operation as succeeded' do
            attributes, _, err = client.update(instance, new_plan, accepts_incomplete: true)

            last_operation = attributes[:last_operation]
            expect(err).to be_nil
            expect(last_operation[:type]).to eq('update')
            expect(last_operation[:state]).to eq('succeeded')
            expect(last_operation[:proposed_changes]).to be_nil
          end
        end

        context 'when the broker returns a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }
          let(:response_data) do
            {}
          end

          it 'return immediately with the broker response' do
            client = Client.new(client_attrs.merge(accepts_incomplete: true))
            attributes, _, error = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:type]).to eq('update')
            expect(attributes[:last_operation][:state]).to eq('in progress')
            expect(attributes[:last_operation][:description]).to eq('')
            expect(attributes[:last_operation][:proposed_changes]).to eq({ service_plan_guid: new_plan.guid })
            expect(error).to be_nil
          end

          context 'when the broker returns an operation' do
            let(:response_data) do
              { operation: 'a_broker_operation_identifier' }
            end

            it 'return immediately with the broker response' do
              attributes, _, error = client.update(instance, new_plan, accepts_incomplete: true)

              expect(attributes[:last_operation][:type]).to eq('update')
              expect(attributes[:last_operation][:state]).to eq('in progress')
              expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
              expect(error).to be_nil
            end
          end
        end
      end

      context 'when the caller passes the user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.update(instance, new_plan, user_guid: user_guid)
          expect(http_client).to have_received(:patch).with(anything, anything, { user_guid: user_guid })
        end
      end

      context 'when the broker returns a operation' do
        let(:response_data) do
          { operation: 'a_broker_operation_identifier' }
        end

        context 'and the response is a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }

          it 'return immediately with the operation from the broker response' do
            client = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to be_nil
          end
        end
      end

      context 'when the broker returns a new dashboard url' do
        context 'and the response is a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }

          let(:response_data) do
            { dashboard_url: 'http://foo.com',
              operation: 'a_broker_operation_identifier' }
          end

          it 'returns immediately with the url from the broker response' do
            client = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)
            expect(attributes[:dashboard_url]).to eq('http://foo.com')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }

          let(:response_data) do
            { dashboard_url: 'http://foo.com' }
          end

          it 'returns immediately with the url from the broker response' do
            client = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)
            expect(attributes[:dashboard_url]).to eq('http://foo.com')
          end
        end
      end

      describe 'error handling' do
        let(:response_parser) { instance_double(ResponseParser) }
        before do
          allow(ResponseParser).to receive(:new).and_return(response_parser)
        end

        describe 'when the http client raises a ServiceBrokerApiTimeout error' do
          let(:error) { Errors::ServiceBrokerApiTimeout.new('some-uri.com', :patch, nil) }
          before do
            allow(http_client).to receive(:patch).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update(instance, new_plan, accepts_incomplete: true)

            expect(err).to eq error
            expect(attrs).to eq({
              last_operation: {
                state: 'failed',
                type: 'update',
                description: error.message,
              }
            })
          end
        end

        describe 'when the response parser raises a ServiceBrokerBadResponse error' do
          let(:response) { instance_double(HttpResponse, code: 500, body: { description: 'BOOOO' }.to_json) }
          let(:error) { Errors::ServiceBrokerBadResponse.new('some-uri.com', :patch, response) }
          before do
            allow(response_parser).to receive(:parse_update).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update(instance, new_plan, accepts_incomplete: true)

            expect(err).to eq error
            expect(attrs).to eq({
              last_operation: {
                state: 'failed',
                type: 'update',
                description: error.message,
              }
            })
          end
        end

        describe 'when the response parser raises a ServiceBrokerResponseMalformed error' do
          let(:response) { instance_double(HttpResponse, code: 200, body: 'some arbitrary body') }
          let(:error) { Errors::ServiceBrokerResponseMalformed.new('some-uri.com', :patch, response, '') }
          before do
            allow(response_parser).to receive(:parse_update).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update(instance, new_plan, accepts_incomplete: true)

            expect(err).to eq error
            expect(attrs).to eq({
              last_operation: {
                state: 'failed',
                type: 'update',
                description: error.message,
              }
            })
          end
        end

        describe 'when the response parser raises a ServiceBrokerRequestRejected error' do
          let(:response) { instance_double(HttpResponse, code: 422, body: { description: 'update not allowed' }.to_json) }
          let(:error) { Errors::ServiceBrokerRequestRejected.new('some-uri.com', :patch, response) }
          before do
            allow(response_parser).to receive(:parse_update).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update(instance, new_plan, accepts_incomplete: 'true')

            expect(err).to eq error
            expect(attrs).to eq({
              last_operation: {
                state: 'failed',
                type: 'update',
                description: error.message,
              }
            })
          end
        end

        describe 'when the response parser raises an AsyncRequired error' do
          let(:response) { instance_double(HttpResponse, code: 422, body: { error: 'AsyncRequired', description: 'update not allowed' }.to_json) }
          let(:error) { Errors::AsyncRequired.new('some-uri.com', :patch, response) }
          before do
            allow(response_parser).to receive(:parse_update).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update(instance, new_plan, accepts_incomplete: 'true')

            expect(err).to eq error
            expect(attrs).to eq({
              last_operation: {
                state: 'failed',
                type: 'update',
                description: error.message,
              }
            })
          end
        end
      end
    end

    describe '#create_service_key' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:key) do
        VCAP::CloudController::ServiceKey.make(
          name: 'fake-service_key',
          service_instance: instance
        )
      end

      let(:response_data) do
        {
          'credentials' => {
            'username' => 'admin',
            'password' => 'secret'
          }
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}/service_bindings/#{key.guid}" }
      let(:response) { HttpResponse.new(body: response_body, code: code, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { 201 }
      let(:message) { 'Created' }
      let(:cc_service_key_client_name) { 'cc-service-key-thingy' }

      before do
        allow(http_client).to receive(:put).and_return(response)
        TestConfig.override(cc_service_key_client_name: cc_service_key_client_name)
      end

      it 'makes a put request with correct path' do
        client.create_service_key(key)

        expect(http_client).to have_received(:put).with(
          "/v2/service_instances/#{instance.guid}/service_bindings/#{key.guid}",
          anything,
          { user_guid: nil }
        )
      end

      it 'makes a put request with correct message' do
        client.create_service_key(key)

        expect(http_client).to have_received(:put).with(
          anything,
          {
            plan_id: key.service_plan.broker_provided_id,
            service_id: key.service.broker_provided_id,
            context: {
              platform: 'cloudfoundry',
              organization_guid: key.service_instance.organization.guid,
              space_guid: key.service_instance.space.guid,
              organization_name: key.service_instance.organization.name,
              space_name: key.service_instance.space.name,
              organization_annotations: {},
              space_annotations: {}
            },
            bind_resource: {
              credential_client_id: cc_service_key_client_name,
            }
          },
          { user_guid: nil }
        )
      end

      context 'when cc_service_key_client is configured' do
        it 'includes the optional credential_client_id parameter' do
          client.create_service_key(key)

          expect(http_client).to have_received(:put).with(
            anything,
            hash_including({ bind_resource: { credential_client_id: cc_service_key_client_name } }),
            { user_guid: nil }
          )
        end
      end

      context 'when cc_service_key_client is NOT present' do
        before do
          TestConfig.override(cc_service_key_client_name: nil)
        end

        it 'does NOT include the optional credential_client_id parameter' do
          client.create_service_key(key)

          expect(http_client).to have_received(:put).with(
            anything,
            hash_excluding({ bind_resource: { credential_client_id: anything } }),
            { user_guid: nil }
          )
        end
      end

      context 'when user_guid is configured' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.create_service_key(key, user_guid: user_guid)

          expect(http_client).to have_received(:put).with(
            anything,
            anything,
            { user_guid: user_guid }
          )
        end
      end

      it 'sets the credentials on the key' do
        attributes = client.create_service_key(key)
        key.set(attributes)
        key.save

        expect(key.credentials).to eq({
          'username' => 'admin',
          'password' => 'secret'
        })
      end

      context 'when the caller provides an arbitrary parameters in an optional request_attrs hash' do
        it 'make a put request with arbitrary parameters' do
          arbitrary_parameters = { 'name' => 'value' }
          client.create_service_key(key, arbitrary_parameters: arbitrary_parameters)
          expect(http_client).to have_received(:put).with(
            anything,
            hash_including(parameters: arbitrary_parameters),
            { user_guid: nil }
          )
        end
      end

      context 'when creating service key fails' do
        let(:uri) { 'some-uri.com/v2/service_instances/instance-guid/service_bindings/key-guid' }

        context 'due to an http client error' do
          before do
            allow(http_client).to receive(:put).and_raise(error)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::HttpClientTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a unbind request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::HttpClientTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key)
            end
          end
        end

        context 'due to a response parser error' do
          let(:response_parser) { instance_double(ResponseParser) }

          before do
            allow(response_parser).to receive(:parse_bind).and_raise(error)
            allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with an unbind request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).not_to have_received(:cleanup_failed_key)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with an unbind request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key)
            end
          end

          context 'ConcurrencyError error' do
            let(:error) { Errors::ConcurrencyError.new(uri, :put, response) }

            it 'propagates the error and does not issue an unbind' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ConcurrencyError)

              expect(orphan_mitigator).not_to have_received(:cleanup_failed_key)
            end
          end

          context 'ServiceBrokerResponseMalformed error' do
            let(:error) { Errors::ServiceBrokerResponseMalformed.new(uri, :put, response, '') }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key)
            end
          end
        end
      end
    end

    describe '#bind' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:app) { VCAP::CloudController::AppModel.make(space: instance.space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          service_instance: instance,
          app: app,
          type: 'app'
        )
      end
      let(:arbitrary_parameters) { {} }

      let(:response_data) do
        {
          'credentials' => {
            'username' => 'admin',
            'password' => 'secret'
          }
        }
      end

      let(:path) { "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:response) { HttpResponse.new(body: response_body, code: code, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { 201 }
      let(:message) { 'Created' }

      before do
        allow(http_client).to receive(:put).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.bind(binding)

        expect(http_client).to have_received(:put).with(
          "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}",
          anything,
          { user_guid: nil }
        )
      end

      it 'makes a put request with correct message' do
        client.bind(binding)

        expect(http_client).to have_received(:put).with(
          anything,
          {
            plan_id: binding.service_plan.broker_provided_id,
            service_id: binding.service.broker_provided_id,
            app_guid: binding.app_guid,
            bind_resource: {
              app_guid: app.guid,
              space_guid: app.space.guid,
              app_annotations: {}
            },
            context: {
              platform: 'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid: instance.space_guid,
              organization_name: instance.organization.name,
              space_name: instance.space.name,
              organization_annotations: {},
              space_annotations: {}
            }
          },
          { user_guid: nil }
        )
      end

      context 'when annotations are set' do
        let!(:public_org_annotation1) {
          VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: instance.organization.guid)
        }
        let!(:public_org_annotation2) {
          VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'bar', value: 'foo', resource_guid: instance.organization.guid)
        }
        let!(:private_org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_name: 'baz', value: 'wow', resource_guid: instance.organization.guid) }
        let!(:public_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'bar', value: 'wow', space: instance.space) }
        let!(:public_legacy_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'pre.fix/wow', value: 'bar', space: instance.space) }
        let!(:private_space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_name: 'bar', value: 'wow', space: instance.space) }

        it 'sends the annotations in the context' do
          client.bind(binding)

          expect(http_client).to have_received(:put).with(
            anything,
            hash_including(
              context: {
                platform: 'cloudfoundry',
                organization_guid: instance.organization.guid,
                space_guid: instance.space_guid,
                organization_name: instance.organization.name,
                space_name: instance.space.name,
                organization_annotations: { 'pre.fix/foo' => 'bar', 'pre.fix/bar' => 'foo' },
                space_annotations: { 'pre.fix/bar' => 'wow', 'pre.fix/wow' => 'bar' }
              }),
            { user_guid: nil }
          )
        end
      end

      it 'sets the credentials on the binding' do
        attributes = client.bind(binding)
        # ensure attributes return match ones for the database
        binding.set(attributes[:binding])
        binding.save

        expect(binding.credentials).to eq({
          'username' => 'admin',
          'password' => 'secret'
        })
      end

      it 'returns async false for synchronous creation' do
        response = client.bind(binding)
        expect(response[:async]).to eq(false)
      end

      context 'when the caller provides an arbitrary parameters in an optional request_attrs hash' do
        let(:arbitrary_parameters) { { 'name' => 'value' } }

        it 'makes a put request with arbitrary parameters' do
          client.bind(binding, arbitrary_parameters: arbitrary_parameters)
          expect(http_client).to have_received(:put).with(
            anything,
            hash_including(parameters: arbitrary_parameters),
            { user_guid: nil }
          )
        end
      end

      context 'when the caller provides accepts_incomplete' do
        context 'when accepts_incomplete=true' do
          let(:accepts_incomplete) { true }

          it 'makes a put request with accepts_incomplete true' do
            client.bind(binding, accepts_incomplete: accepts_incomplete)
            expect(http_client).to have_received(:put).with(
              /accepts_incomplete=true/,
              anything,
              { user_guid: nil }
            )
          end

          context 'and when the broker returns asynchronously' do
            let(:code) { 202 }

            it 'returns async true' do
              response = client.bind(binding, accepts_incomplete: accepts_incomplete)
              expect(response[:async]).to eq(true)
            end

            context 'and when the broker provides operation' do
              let(:response_data) { { operation: '123' } }

              it 'returns the operation attribute' do
                response = client.bind(binding, accepts_incomplete: accepts_incomplete)
                expect(response[:operation]).to eq('123')
              end
            end
          end
        end

        context 'when accepts_incomplete=false' do
          let(:accepts_incomplete) { false }

          it 'makes a put request without the accepts_incomplete query parameter' do
            client.bind(binding, accepts_incomplete: accepts_incomplete)
            expect(http_client).to have_received(:put).with(
              /^((?!accepts_incomplete).)*$/,
              anything,
              { user_guid: nil }
            )
          end
        end
      end

      context 'when the caller provides user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.bind(binding, user_guid: user_guid)
          expect(http_client).to have_received(:put).with(
            anything,
            anything,
            { user_guid: user_guid }
          )
        end
      end

      describe 'bind resource object' do
        context 'app service binding' do
          context 'when the app does not annotations' do
            it 'sends empty annotations object' do
              client.bind(binding)

              expect(http_client).to have_received(:put).with(
                anything,
                hash_including(
                  bind_resource: {
                    app_guid: app.guid,
                    space_guid: app.space.guid,
                    app_annotations: {}
                  }),
                { user_guid: nil }
              )
            end
          end

          context 'when the app has annotations' do
            let!(:annotation1) { VCAP::CloudController::AppAnnotationModel.make(key_name: 'baz', value: 'wow', app: app) }
            let!(:annotation2) { VCAP::CloudController::AppAnnotationModel.make(key_prefix: 'prefix-here.org', key_name: 'foo', value: 'bar', app: app) }
            let!(:annotation3) { VCAP::CloudController::AppAnnotationModel.make(key_name: 'prefix-here.org/wow', value: 'foo', app: app) }

            it 'sends empty annotations object' do
              client.bind(binding)

              expect(http_client).to have_received(:put).with(
                anything,
                hash_including(
                  bind_resource: {
                    app_guid: app.guid,
                    space_guid: app.space.guid,
                    app_annotations: { 'prefix-here.org/foo' => 'bar', 'prefix-here.org/wow' => 'foo' }
                  }),
                { user_guid: nil }
              )
            end
          end
        end

        context 'key service binding' do
          let(:binding) { VCAP::CloudController::ServiceKey.make }

          context 'when cc_service_key_client is configured' do
            it 'includes the optional credential_client_id parameter' do
              client.bind(binding)

              expect(http_client).to have_received(:put).with(
                anything,
                hash_including({ bind_resource: { credential_client_id: 'cc_service_key_client' } }),
                { user_guid: nil }
              )
            end
          end

          context 'when cc_service_key_client is NOT present' do
            before do
              TestConfig.override(cc_service_key_client_name: nil)
            end

            it 'does NOT include the optional credential_client_id parameter' do
              client.bind(binding)

              expect(http_client).to have_received(:put).with(
                anything,
                hash_excluding({ bind_resource: { credential_client_id: anything } }),
                { user_guid: nil }
              )
            end
          end

          it 'does not send the app_guid in the request' do
            client.bind(binding)

            expect(http_client).to have_received(:put).with(
              anything,
              hash_excluding(:app_guid),
              { user_guid: nil }
            )
          end
        end

        context 'route service binding' do
          let(:binding) { VCAP::CloudController::RouteBinding.make }

          it 'sends route bind resource' do
            client.bind(binding)

            expect(http_client).to have_received(:put).with(
              anything,
              hash_including(bind_resource: { route: binding.route.uri }),
              { user_guid: nil }
            )
          end

          it 'does not send the app_guid in the request' do
            client.bind(binding)

            expect(http_client).to have_received(:put).with(
              anything,
              hash_excluding(:app_guid),
              { user_guid: nil }
            )
          end
        end
      end

      context 'with a syslog drain url' do
        before do
          instance.service_plan.service.update_from_hash(requires: ['syslog_drain'])
        end

        let(:response_data) do
          {
            'credentials' => {},
            'syslog_drain_url' => 'syslog://example.com:514'
          }
        end

        it 'sets the syslog_drain_url on the binding' do
          attributes = client.bind(binding)
          # ensure attributes return match ones for the database
          binding.set(attributes[:binding])
          binding.save

          expect(binding.syslog_drain_url).to eq('syslog://example.com:514')
        end

        context 'and the service does not require syslog_drain' do
          before do
            instance.service_plan.service.update_from_hash(requires: [])
          end

          it 'raises an error and initiates orphan mitigation' do
            expect {
              client.bind(binding)
            }.to raise_error(Errors::ServiceBrokerInvalidSyslogDrainUrl)

            expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(binding)
          end
        end
      end

      context 'without a syslog drain url' do
        let(:response_data) do
          {
            'credentials' => {}
          }
        end

        it 'does not set the syslog_drain_url on the binding' do
          client.bind(binding)
          expect(binding.syslog_drain_url).to_not be
        end
      end

      context 'with volume mounts' do
        before do
          instance.service_plan.service.update_from_hash(requires: ['volume_mount'])
        end

        let(:response_data) do
          {
            'volume_mounts' => [
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'olympus' }, 'mode' => 'none', 'container_dir' => 'none', 'driver' => 'none' },
              { 'device_type' => 'none', 'device' => { 'volume_id' => 'everest' }, 'mode' => 'none', 'container_dir' => 'none', 'driver' => 'none' }
            ]
          }
        end

        it 'stores the volume mount on the service binding' do
          attributes = client.bind(binding)

          binding.set(attributes[:binding])
          binding.save

          expect(binding.volume_mounts).to match_array([
            { 'device_type' => 'none', 'device' => { 'volume_id' => 'olympus' }, 'mode' => 'none', 'container_dir' => 'none', 'driver' => 'none' },
            { 'device_type' => 'none', 'device' => { 'volume_id' => 'everest' }, 'mode' => 'none', 'container_dir' => 'none', 'driver' => 'none' }
          ])
        end

        context 'when the volume mounts cause an error to be raised' do
          let(:response_data) do
            {
              'volume_mounts' => 'invalid'
            }
          end

          it 'raises an error and initiates orphan mitigation' do
            expect {
              client.bind(binding)
            }.to raise_error(Errors::ServiceBrokerInvalidVolumeMounts)

            expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(binding)
          end
        end
      end

      context 'when binding fails' do
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
        let(:uri) { 'some-uri.com/v2/service_instances/instance-guid/service_bindings/binding-guid' }
        let(:response) { HttpResponse.new(body: nil, message: nil, code: nil) }

        RSpec.shared_examples 'binding error handling' do
          context 'due to an http client error' do
            let(:http_client) { instance_double(HttpClient) }

            context 'Errors::HttpClientTimeout error' do
              before do
                allow(http_client).to receive(:put).and_raise(
                  Errors::HttpClientTimeout.new(uri, :put, Timeout::Error.new)
                )

                expect {
                  client.bind(binding)
                }.to raise_error(Errors::HttpClientTimeout)
              end

              it 'propagates the error and cleans up the failed binding' do
                expect(orphan_mitigator).to have_received(:cleanup_failed_bind).
                  with(binding)
              end
            end
          end

          context 'due to a response parser error' do
            let(:response_parser) { instance_double(ResponseParser) }

            before do
              allow(response_parser).to receive(:parse_bind).and_raise(error)
              allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
            end

            context 'Errors::ServiceBrokerApiTimeout error' do
              let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

              it 'propagates the error but does not clean up the binding' do
                expect {
                  client.bind(binding)
                }.to raise_error(Errors::ServiceBrokerApiTimeout)

                expect(orphan_mitigator).not_to have_received(:cleanup_failed_bind)
              end
            end

            context 'ServiceBrokerBadResponse error' do
              let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

              it 'propagates the error and follows up with a deprovision request' do
                expect {
                  client.bind(binding)
                }.to raise_error(Errors::ServiceBrokerBadResponse)

                expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(binding)
              end
            end

            context 'ConcurrencyError error' do
              let(:error) { Errors::ConcurrencyError.new(uri, :put, response) }

              it 'propagates the error and does not issue an unbind' do
                expect {
                  client.bind(binding, arbitrary_parameters)
                }.to raise_error(Errors::ConcurrencyError)

                expect(orphan_mitigator).not_to have_received(:cleanup_failed_bind)
              end
            end

            context 'ServiceBrokerResponseMalformed error' do
              let(:error) { Errors::ServiceBrokerResponseMalformed.new(uri, :put, response, '') }

              it 'propagates the error and follows up with a deprovision request' do
                expect {
                  client.bind(binding)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)

                expect(orphan_mitigator).to have_received(:cleanup_failed_bind)
              end

              context 'when the status code was a 200' do
                let(:response) { HttpResponse.new(code: 200, body: nil, message: nil) }

                it 'does not initiate orphan mitigation' do
                  expect {
                    client.bind(binding)
                  }.to raise_error(Errors::ServiceBrokerResponseMalformed)

                  expect(orphan_mitigator).not_to have_received(:cleanup_failed_bind).with(binding)
                end
              end
            end
          end
        end

        context 'app binding' do
          let(:binding) { VCAP::CloudController::ServiceBinding.make }
          it_behaves_like 'binding error handling'
        end

        context 'key binding' do
          let(:binding) { VCAP::CloudController::ServiceKey.make }
          it_behaves_like 'binding error handling'
        end
      end
    end

    describe '#unbind' do
      let(:binding) { VCAP::CloudController::ServiceBinding.make }

      let(:response_data) { {} }

      let(:path) { "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:response) { HttpResponse.new(code: code, body: response_body, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { 200 }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)
      end

      it 'makes a delete request with the correct path' do
        client.unbind(binding)

        expect(http_client).to have_received(:delete).
          with(
            "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}",
            anything,
            { user_guid: nil }
          )
      end

      it 'makes a delete request with correct message' do
        client.unbind(binding)

        expect(http_client).to have_received(:delete).
          with(anything,
            {
              plan_id: binding.service_plan.broker_provided_id,
              service_id: binding.service.broker_provided_id,
            },
            { user_guid: nil }
          )
      end

      context 'when the caller provides user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a delete request with the correct user_guid' do
          client.unbind(binding, user_guid: user_guid)
          expect(http_client).to have_received(:delete).with(anything, anything, { user_guid: user_guid })
        end
      end

      context 'when the broker returns a 204 NO CONTENT' do
        let(:code) { 204 }
        let(:message) { 'NO CONTENT' }

        it 'raises a ServiceBrokerBadResponse error' do
          expect {
            client.unbind(binding)
          }.to raise_error(Errors::ServiceBrokerBadResponse)
        end
      end

      context 'when the broker returns an error' do
        let(:code) { 204 }
        let(:response_data) do
          { 'description' => 'Could not delete binding' }
        end
        let(:response_body) { response_data.to_json }

        it 're-raises the error ' do
          expect {
            client.unbind(binding)
          }.to raise_error(Errors::ServiceBrokerBadResponse).
            with_message('Service broker error: Could not delete binding')
        end
      end

      context 'when the broker responds synchronously' do
        let(:code) { 200 }

        it 'should return async false' do
          unbind_response = client.unbind(binding)
          expect(unbind_response[:async]).to eq(false)
        end
      end

      context 'when the broker responds asynchronously' do
        let(:code) { 202 }

        it 'should return async true' do
          unbind_response = client.unbind(binding)
          expect(unbind_response[:async]).to eq(true)
        end
      end

      context 'when the caller provides accepts_incomplete' do
        before do
          client.unbind(binding, accepts_incomplete: accepts_incomplete)
        end

        context 'when accepts_incomplete=true' do
          let(:accepts_incomplete) { true }

          it 'makes a put request with accepts_incomplete true' do
            expect(http_client).to have_received(:delete).with(/accepts_incomplete=true/, anything, anything)
          end

          context 'and when the broker returns asynchronously' do
            let(:code) { 202 }

            it 'returns async true' do
              response = client.unbind(binding)
              expect(response[:async]).to eq(true)
            end

            context 'and when the broker provides operation' do
              let(:response_data) { { operation: '123' } }

              it 'returns the operation attribute' do
                response = client.unbind(binding, accepts_incomplete: accepts_incomplete)
                expect(response[:operation]).to eq('123')
              end
            end
          end
        end

        context 'when accepts_incomplete=false' do
          let(:accepts_incomplete) { false }

          it 'makes a put request without the accepts_incomplete query parameter' do
            expect(http_client).to have_received(:delete).with(/^((?!accepts_incomplete).)*$/, anything, anything)
          end
        end
      end

      context 'ConcurrencyError error' do
        let(:code) { 422 }
        let(:response_body) { '{"error":"ConcurrencyError"}' }

        context 'for app bindings' do
          it 'propagates the error as an API error' do
            expect { client.unbind(binding) }.to raise_error(CloudController::Errors::ApiError, /An operation for the service binding between app/)
          end
        end

        context 'for a route binding' do
          let(:binding) { VCAP::CloudController::RouteBinding.make }

          it 'propagates the error as a ConcurrencyError' do
            expect { client.unbind(binding) }.to raise_error(Errors::ConcurrencyError)
          end
        end
      end
    end

    describe '#deprovision' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }

      let(:response_data) { {} }

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, body: response_body, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { 200 }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)
      end

      it 'makes a delete request with the correct path' do
        client.deprovision(instance)

        expect(http_client).to have_received(:delete).with(
          "/v2/service_instances/#{instance.guid}",
          anything,
          { user_guid: nil }
        )
      end

      it 'makes a delete request with correct message' do
        client.deprovision(instance)

        expect(http_client).to have_received(:delete).with(
          anything,
          {
            service_id: instance.service.broker_provided_id,
            plan_id: instance.service_plan.broker_provided_id
          },
          { user_guid: nil }
        )
      end

      context 'when the caller does not pass the accepts_incomplete flag' do
        it 'returns a last_operation hash with a state defaulted to `succeeded`' do
          attrs, _ = client.deprovision(instance)
          expect(attrs).to eq({
            last_operation: {
              type: 'delete',
              state: 'succeeded',
              description: ''
            }
          })
        end
      end

      context 'when the caller passes the accepts_incomplete flag' do
        it 'adds the flag to the path of the service broker request' do
          client.deprovision(instance, accepts_incomplete: true)

          expect(http_client).to have_received(:delete).with(
            path,
            hash_including(accepts_incomplete: true),
            { user_guid: nil }
          )
        end

        context 'when the broker returns a 202' do
          let(:code) { 202 }

          it 'returns the last_operation hash' do
            attrs, _ = client.deprovision(instance, accepts_incomplete: true)
            expect(attrs).to eq({
              last_operation: {
                type: 'delete',
                state: 'in progress',
                description: ''
              }
            })
          end

          context 'when the broker provides a operation' do
            let(:response_data) do
              { operation: 'a_broker_operation_identifier' }
            end

            it 'return immediately with the broker response' do
              attributes, _ = client.deprovision(instance, accepts_incomplete: true)

              expect(attributes).to eq({
                last_operation: {
                  type: 'delete',
                  state: 'in progress',
                  description: '',
                  broker_provided_operation: 'a_broker_operation_identifier'
                }
              })
            end
          end
        end

        context 'when the broker returns a 200' do
          let(:code) { 200 }

          it 'returns the last_operation hash' do
            attrs, _ = client.deprovision(instance, accepts_incomplete: true)
            expect(attrs).to eq({
              last_operation: {
                type: 'delete',
                state: 'succeeded',
                description: ''
              }
            })
          end
        end
      end

      context 'when the caller passes the user_guid flag' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.deprovision(instance, user_guid: user_guid)

          expect(http_client).to have_received(:delete).with(
            path,
            anything,
            { user_guid: user_guid }
          )
        end
      end

      context 'when the broker returns a 204 NO CONTENT' do
        let(:code) { 204 }
        let(:message) { 'NO CONTENT' }
        let(:client) { Client.new(client_attrs) }

        it 'raises a ServiceBrokerBadResponse error' do
          expect {
            client.deprovision(instance)
          }.to raise_error(Errors::ServiceBrokerBadResponse)
        end
      end

      context 'when the broker returns an error' do
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
        let(:code) { 204 }
        let(:response_data) do
          { 'description' => 'Could not delete instance' }
        end
        let(:response_body) { response_data.to_json }

        it 'raises a ServiceBrokerBadResponse error with the instance name' do
          expect {
            client.deprovision(instance)
          }.to raise_error(Errors::ServiceBrokerBadResponse).
            with_message("Service instance #{instance.name}: Service broker error: Could not delete instance")
        end
      end

      context 'when the broker returns a operation' do
        let(:response_data) do
          { operation: 'a_broker_operation_identifier' }
        end

        context 'and the response is a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }

          it 'return immediately with the operation from the broker response' do
            client = Client.new(client_attrs)
            attributes = client.deprovision(instance)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client = Client.new(client_attrs)
            attributes = client.deprovision(instance)

            expect(attributes[:last_operation][:broker_provided_operation]).to be_nil
          end
        end
      end
    end

    describe '#fetch_service_binding' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:app) { VCAP::CloudController::AppModel.make(space: instance.space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          service_instance: instance,
          app: app,
          type: 'app'
        )
      end

      let(:broker_response) { HttpResponse.new(code: 200, body: { foo: 'bar' }.to_json) }

      before do
        allow(http_client).to receive(:get).and_return(broker_response)
      end

      it 'makes a get request with the correct path' do
        client.fetch_service_binding(binding)
        expect(http_client).to have_received(:get).with(
          "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}",
          { user_guid: nil }
        )
      end

      it 'returns the broker response' do
        response = client.fetch_service_binding(binding)
        expect(response).to eq({ foo: 'bar' })
      end

      context 'with a user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.fetch_service_binding(binding, user_guid: user_guid)
          expect(http_client).to have_received(:get).with(
            "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}",
            { user_guid: user_guid }
          )
        end
      end
    end

    describe '#fetch_service_instance' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:broker_response) { HttpResponse.new(code: 200, body: { foo: 'bar' }.to_json) }

      before do
        allow(http_client).to receive(:get).and_return(broker_response)
      end

      it 'makes a get request with the correct path' do
        client.fetch_service_instance(instance)
        expect(http_client).to have_received(:get).with(
          "/v2/service_instances/#{instance.guid}",
          { user_guid: nil }
        )
      end

      it 'returns the broker response' do
        response = client.fetch_service_instance(instance)
        expect(response).to eq({ foo: 'bar' })
      end

      context 'with a user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.fetch_service_instance(instance, user_guid: user_guid)
          expect(http_client).to have_received(:get).with(
            "/v2/service_instances/#{instance.guid}",
            { user_guid: user_guid }
          )
        end
      end
    end

    describe '#fetch_service_binding_last_operation' do
      let(:response_data) do
        {
          'state' => 'in progress',
          'description' => '10%'
        }
      end
      let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
      let(:binding_operation) { VCAP::CloudController::ServiceBindingOperation.make }
      let(:broker_response) { HttpResponse.new(code: code, body: response_body) }
      let(:response_body) { response_data.to_json }
      let(:code) { 200 }

      before do
        service_binding.service_binding_operation = binding_operation
        allow(http_client).to receive(:get).and_return(broker_response)
      end

      it 'returns the broker response' do
        response = client.fetch_service_binding_last_operation(service_binding)
        expect(response).to eq({ last_operation: { state: 'in progress', description: '10%' } })
      end

      context 'with a user_guid' do
        let(:user_guid) { Sham.guid }

        it 'makes a request with the correct user_guid' do
          client.fetch_service_binding_last_operation(service_binding, user_guid: user_guid)

          service_id = service_binding.service_instance.service_plan.service.broker_provided_id
          plan_id = service_binding.service_instance.service_plan.broker_provided_id
          query_params = "?plan_id=#{plan_id}&service_id=#{service_id}"

          expect(http_client).to have_received(:get).with(
            "/v2/service_instances/#{service_binding.service_instance.guid}/service_bindings/#{service_binding.guid}/last_operation#{query_params}",
            { user_guid: user_guid }
          )
        end
      end

      context 'when the broker does not provide operation data' do
        it 'makes a get request with the correct path' do
          client.fetch_service_binding_last_operation(service_binding)

          service_id = service_binding.service_instance.service_plan.service.broker_provided_id
          plan_id = service_binding.service_instance.service_plan.broker_provided_id
          query_params = "?plan_id=#{plan_id}&service_id=#{service_id}"

          expect(http_client).to have_received(:get).with(
            "/v2/service_instances/#{service_binding.service_instance.guid}/service_bindings/#{service_binding.guid}/last_operation#{query_params}",
            { user_guid: nil }
          )
        end
      end

      context 'when the broker provides operation data' do
        let(:binding_operation) { VCAP::CloudController::ServiceBindingOperation.make(broker_provided_operation: '123') }

        it 'makes a get request with the correct path' do
          client.fetch_service_binding_last_operation(service_binding)

          service_id = service_binding.service_instance.service_plan.service.broker_provided_id
          plan_id = service_binding.service_instance.service_plan.broker_provided_id
          query_params = "?operation=123&plan_id=#{plan_id}&service_id=#{service_id}"

          expect(http_client).to have_received(:get).with(
            "/v2/service_instances/#{service_binding.service_instance.guid}/service_bindings/#{service_binding.guid}/last_operation#{query_params}",
            { user_guid: nil }
          )
        end
      end

      context 'when the broker returns 410' do
        let(:code) { 410 }
        let(:response_data) { {} }

        context 'when the last operation type is `delete`' do
          before do
            service_binding.save_with_new_operation({ type: 'delete', state: 'in progress' })
          end

          it 'returns attributes to indicate the service instance was deleted' do
            attrs = client.fetch_service_binding_last_operation(service_binding)

            expect(attrs).to include(
              last_operation: {
                state: 'succeeded'
              }
            )
          end
        end

        context 'when the last operation type is `in progress`' do
          before do
            service_binding.save_with_new_operation({ type: 'create', state: 'in progress' })
          end

          it 'returns attributes to indicate the service binding operation is in progress' do
            attrs = client.fetch_service_binding_last_operation(service_binding)

            expect(attrs).to include(
              last_operation: {
                state: 'in progress'
              }
            )
          end
        end
      end

      context 'when the broker returns headers' do
        let(:broker_response) { HttpResponse.new(code: 200, body: response_body, headers: { 'Retry-After' => 10 }) }

        it 'returns the retry after header in the result' do
          attrs = client.fetch_service_binding_last_operation(service_binding)
          expect(attrs).to include(retry_after: 10)
        end
      end
    end

    describe '#fetch_and_handle_service_binding_last_operation' do
      let(:response_data) do
        {
          'state' => 'in progress',
          'description' => '10%'
        }
      end
      let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
      let(:binding_operation) { VCAP::CloudController::ServiceBindingOperation.make }

      let(:code) { 200 }
      let(:response_body) { response_data.to_json }
      let(:broker_response) { HttpResponse.new(code: code, body: response_body) }

      before do
        service_binding.service_binding_operation = binding_operation
        allow(http_client).to receive(:get).and_return(broker_response)
      end

      it 'returns the broker response' do
        response = client.fetch_and_handle_service_binding_last_operation(service_binding)

        expect(response).to eq({ last_operation: { state: 'in progress', description: '10%' } })
      end

      context 'making get request with the correct path' do
        context 'when the broker does not provide operation data' do
          it 'does not pass operation data' do
            client.fetch_and_handle_service_binding_last_operation(service_binding)

            service_id = service_binding.service_instance.service_plan.service.broker_provided_id
            plan_id = service_binding.service_instance.service_plan.broker_provided_id
            query_params = "?plan_id=#{plan_id}&service_id=#{service_id}"

            expect(http_client).to have_received(:get).with(
              "/v2/service_instances/#{service_binding.service_instance.guid}/service_bindings/#{service_binding.guid}/last_operation#{query_params}",
              { user_guid: nil }
            )
          end
        end

        context 'when the broker provides operation data' do
          let(:binding_operation) { VCAP::CloudController::ServiceBindingOperation.make(broker_provided_operation: '123') }

          it 'passes operation data in query params' do
            client.fetch_and_handle_service_binding_last_operation(service_binding)

            service_id = service_binding.service_instance.service_plan.service.broker_provided_id
            plan_id = service_binding.service_instance.service_plan.broker_provided_id
            query_params = "?operation=#{binding_operation.broker_provided_operation}&plan_id=#{plan_id}&service_id=#{service_id}"

            expect(http_client).to have_received(:get).with(
              "/v2/service_instances/#{service_binding.service_instance.guid}/service_bindings/#{service_binding.guid}/last_operation#{query_params}",
              { user_guid: nil }
            )
          end
        end

        context 'with a user_guid' do
          let(:user_guid) { Sham.guid }

          it 'makes a request with the correct user_guid' do
            client.fetch_and_handle_service_binding_last_operation(service_binding, user_guid: user_guid)
            expect(http_client).to have_received(:get).with(anything, { user_guid: user_guid })
          end
        end
      end

      context 'when the broker response means the platform should keep polling' do
        context 'http client errors' do
          errors = [
            Errors::ServiceBrokerApiUnreachable.new('some-uri.com', :get, Errno::ECONNREFUSED.new),
            Errors::HttpClientTimeout.new('some-uri.com', :get, Timeout::Error.new),
            HttpRequestError.new('some failure', 'some-uri.com', :get, RuntimeError.new('some failure'))
          ]

          errors.each do |error|
            context "when error is #{error.class.name}" do
              it 'should return state in progress' do
                allow(http_client).to receive(:get).and_raise(error)

                response = client.fetch_and_handle_service_binding_last_operation(service_binding)

                expect(response[:last_operation][:state]).to eq('in progress')
                expect(response[:last_operation][:description]).to be_nil
              end
            end
          end
        end

        context 'response parsing errors' do
          let(:response_parser) { instance_double(ResponseParser) }
          before do
            allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
          end

          errors = [
            Errors::ServiceBrokerBadResponse.new('some-uri.com', :get, HttpResponse.new(code: nil, body: nil, message: nil)),
            Errors::ServiceBrokerApiAuthenticationFailed.new('some-uri.com', :get, HttpResponse.new(code: nil, body: nil, message: nil)),
            Errors::ServiceBrokerApiTimeout.new('some-uri.com', :get, HttpResponse.new(code: nil, body: nil, message: nil)),
            Errors::ServiceBrokerRequestRejected.new('some-uri.com', :get, HttpResponse.new(code: nil, body: nil, message: nil)),
            Errors::ServiceBrokerResponseMalformed.new('some-uri.com', :get, HttpResponse.new(code: nil, body: nil, message: nil), 'some desc'),
            HttpResponseError.new('some failure', :get, HttpResponse.new(code: nil, body: nil, message: nil))
          ]

          errors.each do |error|
            context "when error is #{error.class.name}" do
              it 'should return state in progress' do
                allow(response_parser).to receive(:parse_fetch_service_binding_last_operation).and_raise(error)

                response = client.fetch_and_handle_service_binding_last_operation(service_binding)

                expect(response[:last_operation][:state]).to eq('in progress')
                expect(response[:last_operation][:description]).to be_nil
              end
            end
          end
        end
      end

      context 'when the broker response means the create binding failed' do
        broker_responses = [
          { code: 400, body: { error: 'BadRequest', description: 'helpful message' }.to_json, description: 'helpful message' },
          { code: 200, body: { state: 'failed', description: 'binding was not created' }.to_json, description: 'binding was not created' },
        ]

        broker_responses.each do |broker_response|
          context "last operation response is #{broker_response[:code]}" do
            let(:code) { broker_response[:code] }
            let(:response_body) { broker_response[:body] }

            it 'should return state failed' do
              lo_result = client.fetch_and_handle_service_binding_last_operation(service_binding)

              expect(lo_result[:last_operation][:state]).to eq('failed')
              expect(lo_result[:last_operation][:description]).to eq(broker_response[:description])
            end
          end
        end
      end

      context 'when the broker returns 410' do
        let(:code) { 410 }
        let(:response_data) { {} }

        context 'when the last operation type is `delete`' do
          before do
            service_binding.save_with_new_operation({ type: 'delete', state: 'in progress' })
          end

          it 'returns attributes to indicate the service instance was deleted' do
            attrs = client.fetch_and_handle_service_binding_last_operation(service_binding)

            expect(attrs).to include(
              last_operation: {
                state: 'succeeded'
              }
            )
          end
        end

        context 'when the last operation type is `in progress`' do
          before do
            service_binding.save_with_new_operation({ type: 'create', state: 'in progress' })
          end

          it 'returns attributes to indicate the service binding operation is in progress' do
            attrs = client.fetch_and_handle_service_binding_last_operation(service_binding)

            expect(attrs).to include(
              last_operation: {
                state: 'in progress'
              }
            )
          end
        end
      end

      context 'when the broker returns headers' do
        let(:broker_response) { HttpResponse.new(code: 200, body: response_body, headers: { 'Retry-After' => 10 }) }

        it 'returns the retry after header in the result' do
          attrs = client.fetch_and_handle_service_binding_last_operation(service_binding)
          expect(attrs).to include(retry_after: 10)
        end
      end
    end

    def unwrap_delayed_job(job)
      job.payload_object.handler.handler.handler
    end
  end
end
