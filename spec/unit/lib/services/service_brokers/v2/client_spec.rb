require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe Client do
    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

    let(:client_attrs) {
      {
        url:           service_broker.broker_url,
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
              'id'          => service_id,
              'name'        => service_name,
              'description' => service_description,
              'plans'       => [
                {
                  'id'          => plan_id,
                  'name'        => plan_name,
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
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:get).with(path).and_return(catalog_response)
      end

      it 'returns a catalog' do
        expect(client.catalog).to eq(response_data)
      end
    end

    describe '#provision' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance_operation) { VCAP::CloudController::ServiceInstanceOperation.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: plan,
          space:        space
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
      let(:code) { '201' }
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
          with(path, anything)
      end

      context 'when the caller passes the accepts_incomplete flag' do
        let(:path) { "/v2/service_instances/#{instance.guid}?accepts_incomplete=true" }

        it 'adds the flag to the path of the service broker request' do
          client.provision(instance, accepts_incomplete: true)

          expect(http_client).to have_received(:put).
            with(path, anything)
        end
      end

      it 'makes a put request with correct message' do
        client.provision(instance)

        expect(http_client).to have_received(:put).with(
          anything,
          service_id:        instance.service.broker_provided_id,
          plan_id:           instance.service_plan.broker_provided_id,
          organization_guid: instance.organization.guid,
          space_guid:        instance.space.guid,
          context:           {
            platform:          'cloudfoundry',
            organization_guid: instance.organization.guid,
            space_guid:        instance.space_guid
          }
        )
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
        expect(http_client).to have_received(:put).with(path, hash_including(parameters: arbitrary_parameters))
      end

      context 'when the broker returns 204 (No Content)' do
        let(:code) { '204' }
        let(:client) { Client.new(client_attrs) }

        it 'raises ServiceBrokerBadResponse and initiates orphan mitigation' do
          expect {
            client.provision(instance)
          }.to raise_error(Errors::ServiceBrokerBadResponse)

          expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
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
            client        = Client.new(client_attrs)
            attributes, _ = client.provision(instance, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client        = Client.new(client_attrs)
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
          client        = Client.new(client_attrs)
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

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
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

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).
                with(client_attrs, instance)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
            end
          end

          context 'ServiceBrokerResponseMalformed error' do
            let(:error) { Errors::ServiceBrokerResponseMalformed.new(uri, :put, response, '') }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
            end

            context 'when the status code was a 200' do
              let(:response) { HttpResponse.new(code: 200, body: nil, message: nil) }

              it 'does not initiate orphan mitigation' do
                expect {
                  client.provision(instance)
                }.to raise_error(Errors::ServiceBrokerResponseMalformed)

                expect(orphan_mitigator).not_to have_received(:cleanup_failed_provision).with(client_attrs, instance)
              end
            end
          end
        end
      end
    end

    describe '#fetch_service_instance_state' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: plan,
          space:        space
        )
      end

      let(:response_data) do
        {
          'state'       => 'succeeded',
          'description' => '100% created'
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, message: message, body: response_body) }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }
      let(:broker_provided_operation) { nil }

      before do
        instance.save_with_new_operation({}, { type: 'create', broker_provided_operation: broker_provided_operation })
        allow(http_client).to receive(:get).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.fetch_service_instance_state(instance)

        expect(http_client).to have_received(:get).
          with("/v2/service_instances/#{instance.guid}/last_operation?plan_id=#{plan.broker_provided_id}&service_id=#{instance.service.broker_provided_id}")
      end
      context 'when the broker operation id is specified' do
        let(:broker_provided_operation) { 'a_broker_provided_operation' }
        it 'makes a put request with correct path' do
          client.fetch_service_instance_state(instance)

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

      it 'returns the attributes to update the service instance model' do
        attrs          = client.fetch_service_instance_state(instance)
        expected_attrs = { last_operation: response_data.symbolize_keys }
        expect(attrs).to eq(expected_attrs)
      end

      context 'when the broker provides other fields' do
        let(:response_data) do
          {
            'state'       => 'succeeded',
            'description' => '100% created',
            'foo'         => 'bar'
          }
        end

        it 'passes through the extra fields' do
          attrs = client.fetch_service_instance_state(instance)
          expect(attrs[:foo]).to eq 'bar'
          expect(attrs[:last_operation]).to eq({ state: 'succeeded', description: '100% created' })
        end
      end

      context 'when the broker returns 410' do
        let(:code) { '410' }
        let(:message) { 'GONE' }
        let(:response_data) do
          {}
        end

        context 'when the last operation type is `delete`' do
          before do
            instance.save_with_new_operation({}, { type: 'delete' })
          end

          it 'returns attributes to indicate the service instance was deleted' do
            attrs = client.fetch_service_instance_state(instance)
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

          it 'returns attributes to indicate the service instance operation failed' do
            attrs = client.fetch_service_instance_state(instance)
            expect(attrs).to include(
              last_operation: {
                state: 'failed'
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
          attrs = client.fetch_service_instance_state(instance)
          expect(attrs).to eq({ last_operation: { state: 'succeeded' } })
        end
      end
    end

    describe '#update' do
      let(:old_plan) { VCAP::CloudController::ServicePlan.make }
      let(:new_plan) { VCAP::CloudController::ServicePlan.make }

      let(:space) { VCAP::CloudController::Space.make }
      let(:last_operation) do
        VCAP::CloudController::ServiceInstanceOperation.make(
          type:  'create',
          state: 'succeeded'
        )
      end

      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: old_plan,
          space:        space
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

        expect(http_client).to have_received(:patch).with(anything,
          hash_including({
            service_id: instance.service.broker_provided_id,
          })
        )
      end

      it 'makes a patch request with the correct context in the body' do
        client.update(instance, new_plan, previous_values: { plan_id: '1234' })

        expect(http_client).to have_received(:patch).with(anything,
          hash_including({
            context: {
              platform:          'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid:        instance.space_guid
            }
          })
        )
      end

      it 'makes a patch request to the correct path' do
        client.update(instance, new_plan)
        expect(http_client).to have_received(:patch).with(path, anything)
      end

      context 'when the caller passes a new service plan' do
        it 'makes a patch request with the new service plan' do
          client.update(instance, new_plan, previous_values: { plan_id: '1234' })

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including({
              plan_id:         new_plan.broker_provided_id,
              previous_values: {
                plan_id: '1234'
              }
            })
          )
        end
      end

      context 'when the caller passes arbitrary parameters' do
        it 'includes the parameters in the request to the broker' do
          client.update(instance, old_plan, arbitrary_parameters: { myParam: 'some-value' })

          expect(http_client).to have_received(:patch).with(
            anything,
            hash_including({
              parameters:      { myParam: 'some-value' },
              previous_values: {}
            })
          )
        end
      end

      context 'when the caller passes the accepts_incomplete flag' do
        let(:path) { "/v2/service_instances/#{instance.guid}?accepts_incomplete=true" }

        it 'adds the flag to the path of the service broker request' do
          client.update(instance, new_plan, accepts_incomplete: true)

          expect(http_client).to have_received(:patch).
            with(path, anything)
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

          it 'returns the new service_plan in a hash' do
            attributes, _, err = client.update(instance, new_plan, accepts_incomplete: true)
            expect(err).to be_nil
            expect(attributes[:service_plan]).to eq new_plan
          end
        end

        context 'when the broker returns a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }
          let(:response_data) do
            {}
          end

          it 'return immediately with the broker response' do
            client               = Client.new(client_attrs.merge(accepts_incomplete: true))
            attributes, _, error = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:type]).to eq('update')
            expect(attributes[:last_operation][:state]).to eq('in progress')
            expect(attributes[:last_operation][:description]).to eq('')
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

      context 'when the broker returns a operation' do
        let(:response_data) do
          { operation: 'a_broker_operation_identifier' }
        end

        context 'and the response is a 202' do
          let(:code) { 202 }
          let(:message) { 'Accepted' }

          it 'return immediately with the operation from the broker response' do
            client        = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client        = Client.new(client_attrs)
            attributes, _ = client.update(instance, new_plan, accepts_incomplete: true)

            expect(attributes[:last_operation][:broker_provided_operation]).to be_nil
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
                state:       'failed',
                type:        'update',
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
                state:       'failed',
                type:        'update',
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
                state:       'failed',
                type:        'update',
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
                state:       'failed',
                type:        'update',
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
                state:       'failed',
                type:        'update',
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
        VCAP::CloudController::ServiceKey.new(
          name:             'fake-service_key',
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
      let(:code) { '201' }
      let(:message) { 'Created' }

      before do
        allow(http_client).to receive(:put).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.create_service_key(key)

        expect(http_client).to have_received(:put).with("/v2/service_instances/#{instance.guid}/service_bindings/#{key.guid}", anything)
      end

      it 'makes a put request with correct message' do
        client.create_service_key(key)

        expect(http_client).to have_received(:put).
          with(anything,
            plan_id:    key.service_plan.broker_provided_id,
            service_id: key.service.broker_provided_id,
            context:    {
              platform:          'cloudfoundry',
              organization_guid: key.service_instance.organization.guid,
              space_guid:        key.service_instance.space.guid
            }
          )
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
          expect(http_client).to have_received(:put).
            with(anything,
              hash_including(
                parameters: arbitrary_parameters
              )
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
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key).
                with(client_attrs, key)
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

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key).with(client_attrs, key)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.create_service_key(key)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_key).with(client_attrs, key)
            end
          end
        end
      end
    end

    describe '#bind' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:app) { VCAP::CloudController::AppModel.make(space: instance.space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.new(
          service_instance: instance,
          app:              app,
          type:             'app'
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
      let(:code) { '201' }
      let(:message) { 'Created' }

      before do
        allow(http_client).to receive(:put).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.bind(binding, arbitrary_parameters)

        expect(http_client).to have_received(:put).
          with("/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}", anything)
      end

      it 'makes a put request with correct message' do
        client.bind(binding, arbitrary_parameters)

        expect(http_client).to have_received(:put).
          with(anything,
            plan_id:       binding.service_plan.broker_provided_id,
            service_id:    binding.service.broker_provided_id,
            app_guid:      binding.app_guid,
            bind_resource: binding.required_parameters,
            context:       {
              platform:          'cloudfoundry',
              organization_guid: instance.organization.guid,
              space_guid:        instance.space_guid
            }
          )
      end

      it 'sets the credentials on the binding' do
        attributes = client.bind(binding, arbitrary_parameters)
        # ensure attributes return match ones for the database
        binding.set(attributes)
        binding.save

        expect(binding.credentials).to eq({
          'username' => 'admin',
          'password' => 'secret'
        })
      end

      context 'when the caller provides an arbitrary parameters in an optional request_attrs hash' do
        let(:arbitrary_parameters) { { 'name' => 'value' } }

        it 'make a put request with arbitrary parameters' do
          client.bind(binding, arbitrary_parameters)
          expect(http_client).to have_received(:put).
            with(anything,
              hash_including(
                parameters: arbitrary_parameters
              )
            )
        end
      end

      context 'when the binding does not have an app_guid' do
        let(:binding) { VCAP::CloudController::RouteBinding.make }

        it 'does not send the app_guid in the request' do
          client.bind(binding, arbitrary_parameters)

          expect(http_client).to have_received(:put).
            with(anything,
              hash_excluding(:app_guid)
            )
        end
      end

      context 'with a syslog drain url' do
        before do
          instance.service_plan.service.update_from_hash(requires: ['syslog_drain'])
        end

        let(:response_data) do
          {
            'credentials'      => {},
            'syslog_drain_url' => 'syslog://example.com:514'
          }
        end

        it 'sets the syslog_drain_url on the binding' do
          attributes = client.bind(binding, arbitrary_parameters)
          # ensure attributes return match ones for the database
          binding.set(attributes)
          binding.save

          expect(binding.syslog_drain_url).to eq('syslog://example.com:514')
        end

        context 'and the service does not require syslog_drain' do
          before do
            instance.service_plan.service.update_from_hash(requires: [])
          end

          it 'raises an error and initiates orphan mitigation' do
            expect {
              client.bind(binding, arbitrary_parameters)
            }.to raise_error(Errors::ServiceBrokerInvalidSyslogDrainUrl)

            expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
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
          client.bind(binding, arbitrary_parameters)
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
          attributes = client.bind(binding, arbitrary_parameters)

          binding.set(attributes)
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
              client.bind(binding, arbitrary_parameters)
            }.to raise_error(Errors::ServiceBrokerInvalidVolumeMounts)

            expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
          end
        end
      end

      context 'when binding fails' do
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
        let(:binding) { VCAP::CloudController::ServiceBinding.make }
        let(:uri) { 'some-uri.com/v2/service_instances/instance-guid/service_bindings/binding-guid' }
        let(:response) { HttpResponse.new(body: nil, message: nil, code: nil) }

        context 'due to an http client error' do
          let(:http_client) { instance_double(HttpClient) }

          before do
            allow(http_client).to receive(:put).and_raise(error)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.bind(binding, arbitrary_parameters)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).
                with(client_attrs, binding)
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

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.bind(binding, arbitrary_parameters)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.bind(binding, arbitrary_parameters)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
            end
          end
        end
      end
    end

    describe '#unbind' do
      let(:binding) { VCAP::CloudController::ServiceBinding.make }

      let(:response_data) { {} }

      let(:path) { "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:response) { HttpResponse.new(code: code, body: response_body, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)
      end

      it 'makes a delete request with the correct path' do
        client.unbind(binding)

        expect(http_client).to have_received(:delete).
          with("/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}", anything)
      end

      it 'makes a delete request with correct message' do
        client.unbind(binding)

        expect(http_client).to have_received(:delete).
          with(anything,
            {
              plan_id:    binding.service_plan.broker_provided_id,
              service_id: binding.service.broker_provided_id,
            }
          )
      end

      context 'when the broker returns a 204 NO CONTENT' do
        let(:code) { '204' }
        let(:message) { 'NO CONTENT' }

        it 'raises a ServiceBrokerBadResponse error' do
          expect {
            client.unbind(binding)
          }.to raise_error(Errors::ServiceBrokerBadResponse)
        end
      end

      context 'when the broker returns an error' do
        let(:code) { '204' }
        let(:response_data) do
          { 'description' => 'Could not delete instance' }
        end
        let(:response_body) { response_data.to_json }

        it 'raises a ServiceBrokerBadResponse error with the instance name' do
          expect {
            client.unbind(binding)
          }.to raise_error(Errors::ServiceBrokerBadResponse).
            with_message("Service instance #{binding.service_instance.name}: Service broker error: Could not delete instance")
        end
      end
    end

    describe '#deprovision' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }

      let(:response_data) { {} }

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, body: response_body, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)
      end

      it 'makes a delete request with the correct path' do
        client.deprovision(instance)

        expect(http_client).to have_received(:delete).
          with("/v2/service_instances/#{instance.guid}", anything)
      end

      it 'makes a delete request with correct message' do
        client.deprovision(instance)

        expect(http_client).to have_received(:delete).with(
          anything,
          {
            service_id: instance.service.broker_provided_id,
            plan_id:    instance.service_plan.broker_provided_id
          }
        )
      end

      context 'when the caller does not pass the accepts_incomplete flag' do
        it 'returns a last_operation hash with a state defaulted to `succeeded`' do
          attrs, _ = client.deprovision(instance)
          expect(attrs).to eq({
            last_operation: {
              type:        'delete',
              state:       'succeeded',
              description: ''
            }
          })
        end
      end

      context 'when the caller passes the accepts_incomplete flag' do
        it 'adds the flag to the path of the service broker request' do
          client.deprovision(instance, accepts_incomplete: true)

          expect(http_client).to have_received(:delete).
            with(path, hash_including(accepts_incomplete: true))
        end

        context 'when the broker returns a 202' do
          let(:code) { 202 }

          it 'returns the last_operation hash' do
            attrs, _ = client.deprovision(instance, accepts_incomplete: true)
            expect(attrs).to eq({
              last_operation: {
                type:        'delete',
                state:       'in progress',
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
                  type:                      'delete',
                  state:                     'in progress',
                  description:               '',
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
                type:        'delete',
                state:       'succeeded',
                description: ''
              }
            })
          end
        end
      end

      context 'when the broker returns a 204 NO CONTENT' do
        let(:code) { '204' }
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
        let(:code) { '204' }
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
            client     = Client.new(client_attrs)
            attributes = client.deprovision(instance)

            expect(attributes[:last_operation][:broker_provided_operation]).to eq('a_broker_operation_identifier')
          end
        end

        context 'and the response is 200' do
          let(:code) { 200 }
          it 'ignores the operation' do
            client     = Client.new(client_attrs)
            attributes = client.deprovision(instance)

            expect(attributes[:last_operation][:broker_provided_operation]).to be_nil
          end
        end
      end
    end

    def unwrap_delayed_job(job)
      job.payload_object.handler.handler.handler
    end
  end
end
