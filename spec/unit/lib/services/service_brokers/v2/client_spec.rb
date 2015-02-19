require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  describe Client do
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
    let(:orphan_mitigator) { instance_double(OrphanMitigator, cleanup_failed_provision: nil, cleanup_failed_bind: nil) }
    let(:state_poller) { instance_double(ServiceInstanceStatePoller, poll_service_instance_state: nil) }

    before do
      allow(HttpClient).to receive(:new).
        with(url: service_broker.broker_url, auth_username: service_broker.auth_username, auth_password: service_broker.auth_password).
        and_return(http_client)

      allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).
        and_return(orphan_mitigator)

      allow(VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller).to receive(:new).
        and_return(state_poller)

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
          space: space
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
      let(:options) do
        {
          event_repository_opts: nil,
          request_attrs: {}
        }
      end

      before do
        allow(http_client).to receive(:put).and_return(response)
        allow(http_client).to receive(:delete).and_return(response)

        instance.service_instance_operation = service_instance_operation
      end

      it 'makes a put request with correct path' do
        client.provision(instance, options)

        expect(http_client).to have_received(:put).
          with(path, anything)
      end

      it 'makes a put request with correct message' do
        client.provision(instance, options)

        expect(http_client).to have_received(:put).
          with(anything,
            service_id:        instance.service.broker_provided_id,
            plan_id:           instance.service_plan.broker_provided_id,
            organization_guid: instance.organization.guid,
            space_guid:        instance.space.guid
          )
      end

      it 'returns the attributes to update on a service instance' do
        attributes, error = client.provision(instance, options)
        # ensure updating attributes and saving to service instance works
        instance.save_with_operation(attributes)

        expect(instance.dashboard_url).to eq('foo')
        expect(error).to be_nil
      end

      it 'defaults the state to "succeeded"' do
        attributes, error = client.provision(instance, options)

        expect(attributes[:last_operation][:state]).to eq('succeeded')
        expect(error).to be_nil
      end

      it 'leaves the description blank' do
        attributes, error = client.provision(instance, options)

        expect(attributes[:last_operation][:description]).to eq('')
        expect(error).to be_nil
      end

      it 'DEPRECATED, maintain for database not null contraint: sets the credentials on the instance' do
        attributes, error = client.provision(instance, options)

        expect(attributes[:credentials]).to eq({})
        expect(error).to be_nil
      end

      context 'when the broker returns 204 (No Content)' do
        let(:code) { '204' }
        let(:client) { Client.new(client_attrs) }

        it 'throws ServiceBrokerBadResponse and initiates orphan mitigation' do
          expect {
            client.provision(instance, options)
          }.to raise_error(Errors::ServiceBrokerBadResponse)

          expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
        end
      end

      context 'when the broker returns no state or the state is created, or succeeded' do
        let(:response_data) do
          {
            'last_operation' => {}
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          attributes, error = client.provision(instance, options)

          expect(attributes[:last_operation][:type]).to eq('create')
          expect(attributes[:last_operation][:state]).to eq('succeeded')
          expect(attributes[:last_operation][:description]).to eq('')
          expect(error).to be_nil
        end

        it 'does not enqueue a polling job' do
          client.provision(instance, options)
          expect(state_poller).to_not have_received(:poll_service_instance_state)
        end
      end

      context 'when the broker returns no description' do
        let(:response_data) do
          {
            'last_operation' => { 'state' => 'succeeded' }
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          attributes, error = client.provision(instance, options)

          expect(attributes[:last_operation][:type]).to eq('create')
          expect(attributes[:last_operation][:state]).to eq('succeeded')
          expect(attributes[:last_operation][:description]).to eq('')
          expect(error).to be_nil
        end

        it 'does not enqueue a polling job' do
          client.provision(instance, options)
          expect(state_poller).to_not have_received(:poll_service_instance_state)
        end
      end

      context 'when the broker returns the state as `in progress`' do
        let(:code) { 202 }
        let(:message) { 'Accepted' }
        let(:response_data) do
          {
            last_operation: {
              state: 'in progress',
              description: '10% done'
            },
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          attributes, error = client.provision(instance, options)

          expect(attributes[:last_operation][:type]).to eq('create')
          expect(attributes[:last_operation][:state]).to eq('in progress')
          expect(attributes[:last_operation][:description]).to eq('10% done')
          expect(error).to be_nil
        end

        it 'enqueues a polling job' do
          client.provision(instance, options)
          expect(state_poller).to have_received(:poll_service_instance_state).with(client_attrs, instance, options[:event_repository_opts], options[:request_attrs])
        end
      end

      context 'when the broker returns the state as failed' do
        let(:code) { 400 }
        let(:message) { 'Failed' }
        let(:response_data) do
          {
            description: '100% failed'
          }
        end

        it 'raises an error' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          expect { client.provision(instance, options) }.to raise_error(Errors::ServiceBrokerRequestRejected)
        end

        it 'does not enqueue a polling job' do
          client.provision(instance, options) rescue nil
          expect(state_poller).to_not have_received(:poll_service_instance_state)
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
                client.provision(instance, options)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
            end
          end
        end

        context 'due to a response parser error' do
          let(:response_parser) { instance_double(ResponseParser) }

          before do
            allow(response_parser).to receive(:parse).and_raise(error)
            allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance, options)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).
                with(client_attrs, instance)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance, options)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
            end
          end

          context 'ServiceBrokerResponseMalformed error' do
            let(:error) { Errors::ServiceBrokerResponseMalformed.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.provision(instance, options)
              }.to raise_error(Errors::ServiceBrokerResponseMalformed)

              expect(orphan_mitigator).to have_received(:cleanup_failed_provision).with(client_attrs, instance)
            end

            context 'when the status code was a 200' do
              let(:response) { HttpResponse.new(code: 200, body: nil, message: nil) }

              it 'does not initiate orphan mitigation' do
                expect {
                  client.provision(instance, options)
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
          space: space
        )
      end

      let(:response_data) do
        {
          'dashboard_url' => 'bar',
          'last_operation' => {
            'state' => 'succeeded',
            'description' => '100% created'
          }
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { HttpResponse.new(code: code, message: message, body: response_body) }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        instance.save_with_operation(
          last_operation: { type: 'create' }
        )
        allow(http_client).to receive(:get).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.fetch_service_instance_state(instance)

        expect(http_client).to have_received(:get).
          with("/v2/service_instances/#{instance.guid}")
      end

      it 'returns the attributes to update the service instance model' do
        attrs = client.fetch_service_instance_state(instance)
        expected_attrs = response_data.symbolize_keys
        expected_attrs[:last_operation] = response_data['last_operation'].symbolize_keys
        expect(attrs).to eq(expected_attrs)
      end

      context 'when the broker returns 410' do
        let(:code) { '410' }
        let(:message) { 'GONE' }
        let(:response_data) do
          {}
        end

        context 'and the operation type is delete' do
          before do
            instance.save_with_operation(
              last_operation: {
                type: 'delete'
              }
            )
          end

          it 'returns attributes to indicate the service instance was deleted' do
            attrs = client.fetch_service_instance_state(instance)
            expect(attrs[:last_operation]).to include({
              state: 'succeeded',
              description: ''
            })
          end
        end

        context 'and the operation type is not delete' do
          it 'raises Error::ServiceBrokerBadResponse' do
            expect {
              client.fetch_service_instance_state(instance)
            }.to raise_error(Errors::ServiceBrokerBadResponse)
          end
        end
      end
    end

    describe '#update_service_plan' do
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
          space: space
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

      it 'makes a patch request with the new service plan' do
        client.update_service_plan(instance, new_plan)

        expect(http_client).to have_received(:patch).with(
          anything,
          {
            plan_id:	new_plan.broker_provided_id,
            previous_values: {
              plan_id: old_plan.broker_provided_id,
              service_id: old_plan.service.broker_provided_id,
              organization_id: instance.organization.guid,
              space_id: instance.space.guid
            }
          }
        )
      end

      it 'makes a patch request to the correct path' do
        client.update_service_plan(instance, new_plan)

        expect(http_client).to have_received(:patch).with(path, anything)
      end

      context 'when the broker returns a last_operation' do
        let(:response_data) do
          {
            last_operation: {
              state: 'in progress',
              description: 'updating all the things (10%)'
            }
          }
        end

        it 'forwards the last operation state from the broker' do
          attributes, err = client.update_service_plan(instance, new_plan, async: true)

          last_operation = attributes[:last_operation]
          expect(err).to be_nil
          expect(last_operation[:type]).to eq('update')
          expect(last_operation[:state]).to eq('in progress')
          expect(last_operation[:description]).to eq('updating all the things (10%)')
          expect(last_operation[:proposed_changes]).to eq({ service_plan_guid: new_plan.guid })
        end
      end

      context 'when the broker does not return a last_operation' do
        let(:response_data) { { bogus_key: 'bogus_value' } }

        it 'defaults the last operation state to `succeeded`' do
          attributes, err = client.update_service_plan(instance, new_plan, async: true)

          last_operation = attributes[:last_operation]
          expect(err).to be_nil
          expect(last_operation[:type]).to eq('update')
          expect(last_operation[:state]).to eq('succeeded')
          expect(last_operation[:description]).to eq('')
          expect(last_operation[:proposed_changes]).to be_nil
        end

        it 'returns the new service_plan in a hash' do
          attributes, err = client.update_service_plan(instance, new_plan, async: true)
          expect(err).to be_nil
          expect(attributes[:service_plan]).to eq new_plan
        end
      end

      context 'when the broker returns the state as `in progress`' do
        let(:code) { 202 }
        let(:message) { 'Accepted' }
        let(:response_data) do
          {
            last_operation: {
              state: 'in progress',
              description: '10% done'
            },
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          attributes, error = client.update_service_plan(instance, new_plan, async: true)

          expect(attributes[:last_operation][:type]).to eq('update')
          expect(attributes[:last_operation][:state]).to eq('in progress')
          expect(attributes[:last_operation][:description]).to eq('10% done')
          expect(error).to be_nil
        end

        it 'enqueues a polling job' do
          client.update_service_plan(instance, new_plan, async: true)
          expect(state_poller).to have_received(:poll_service_instance_state).with(client_attrs, instance)
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
            attrs, err = client.update_service_plan(instance, new_plan, { async: 'true' })

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
            allow(response_parser).to receive(:parse).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update_service_plan(instance, new_plan, { async: 'true' })

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
          let(:error) { Errors::ServiceBrokerResponseMalformed.new('some-uri.com', :patch, response) }
          before do
            allow(response_parser).to receive(:parse).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update_service_plan(instance, new_plan, { async: 'true' })

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
            allow(response_parser).to receive(:parse).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update_service_plan(instance, new_plan, { async: 'true' })

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
            allow(response_parser).to receive(:parse).and_raise(error)
          end

          it 'returns an array containing the update attributes and the error' do
            attrs, err = client.update_service_plan(instance, new_plan, { async: 'true' })

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

    describe '#bind' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:app) { VCAP::CloudController::App.make(space: instance.space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.new(
          service_instance: instance,
          app: app
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

      let(:path) { "/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}" }
      let(:response) { HttpResponse.new(body: response_body, code: code, message: message) }
      let(:response_body) { response_data.to_json }
      let(:code) { '201' }
      let(:message) { 'Created' }

      before do
        instance.service_plan.service.update_from_hash(requires: ['syslog_drain'])
        allow(http_client).to receive(:put).and_return(response)
      end

      it 'makes a put request with correct path' do
        client.bind(binding)

        expect(http_client).to have_received(:put).
          with("/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}", anything)
      end

      it 'makes a put request with correct message' do
        client.bind(binding)

        expect(http_client).to have_received(:put).
          with(anything,
             plan_id:    binding.service_plan.broker_provided_id,
             service_id: binding.service.broker_provided_id,
             app_guid:   binding.app_guid
        )
      end

      it 'sets the credentials on the binding' do
        attributes = client.bind(binding)
        # ensure attributes return match ones for the database
        binding.set_all(attributes)
        binding.save

        expect(binding.credentials).to eq({
          'username' => 'admin',
          'password' => 'secret'
        })
      end

      context 'with a syslog drain url' do
        let(:response_data) do
          {
            'credentials' => {},
            'syslog_drain_url' => 'syslog://example.com:514'
          }
        end

        it 'sets the syslog_drain_url on the binding' do
          attributes = client.bind(binding)
          # ensure attributes return match ones for the database
          binding.set_all(attributes)
          binding.save

          expect(binding.syslog_drain_url).to eq('syslog://example.com:514')
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

      context 'when binding fails' do
        let(:binding) do
          VCAP::CloudController::ServiceBinding.make(
            binding_options: { 'this' => 'that' }
          )
        end
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
                client.bind(binding)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).
                with(client_attrs, binding)
            end
          end
        end

        context 'due to a response parser error' do
          let(:response_parser) { instance_double(ResponseParser) }

          before do
            allow(response_parser).to receive(:parse).and_raise(error)
            allow(VCAP::Services::ServiceBrokers::V2::ResponseParser).to receive(:new).and_return(response_parser)
          end

          context 'Errors::ServiceBrokerApiTimeout error' do
            let(:error) { Errors::ServiceBrokerApiTimeout.new(uri, :put, Timeout::Error.new) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.bind(binding)
              }.to raise_error(Errors::ServiceBrokerApiTimeout)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
            end
          end

          context 'ServiceBrokerBadResponse error' do
            let(:error) { Errors::ServiceBrokerBadResponse.new(uri, :put, response) }

            it 'propagates the error and follows up with a deprovision request' do
              expect {
                client.bind(binding)
              }.to raise_error(Errors::ServiceBrokerBadResponse)

              expect(orphan_mitigator).to have_received(:cleanup_failed_bind).with(client_attrs, binding)
            end
          end
        end
      end
    end

    describe '#unbind' do
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end

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

        expect(http_client).to have_received(:delete).
          with(anything,
               {
            service_id: instance.service.broker_provided_id,
            plan_id:    instance.service_plan.broker_provided_id
          }
              )
      end
    end
  end
end
