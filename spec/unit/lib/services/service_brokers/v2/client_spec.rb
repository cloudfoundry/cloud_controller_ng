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

    let(:http_client) { double('http_client') }
    let(:orphan_mitigator) { double('orphan_mitigator', cleanup_failed_provision: nil, cleanup_failed_bind: nil) }
    let(:state_poller) { double('state_poller', poll_service_instance_state: nil) }

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
      let(:catalog_response) { double('catalog_response') }
      let(:catalog_response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:get).with(path).and_return(catalog_response)

        allow(catalog_response).to receive(:body).and_return(catalog_response_body)
        allow(catalog_response).to receive(:code).and_return(code)
        allow(catalog_response).to receive(:message).and_return(message)
      end

      it 'returns a catalog' do
        expect(client.catalog).to eq(response_data)
      end
    end

    describe '#provision' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.new(
          service_plan: plan,
          space: space
        )
      end

      let(:response_data) do
        {
          'dashboard_url' => 'foo'
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}?accepts_incomplete=true" }
      let(:response) { double('response') }
      let(:response_body) { response_data.to_json }
      let(:code) { '201' }
      let(:message) { 'Created' }

      before do
        allow(http_client).to receive(:put).and_return(response)
        allow(http_client).to receive(:delete).and_return(response)

        allow(response).to receive(:body).and_return(response_body)
        allow(response).to receive(:code).and_return(code)
        allow(response).to receive(:message).and_return(message)
      end

      it 'makes a put request with correct path' do
        client.provision(instance)

        expect(http_client).to have_received(:put).
          with("/v2/service_instances/#{instance.guid}?accepts_incomplete=true", anything)
      end

      it 'makes a put request with correct message' do
        client.provision(instance)

        expect(http_client).to have_received(:put).
          with(anything,
               {
            service_id:        instance.service.broker_provided_id,
            plan_id:           instance.service_plan.broker_provided_id,
            organization_guid: instance.organization.guid,
            space_guid:        instance.space.guid
          }
              )
      end

      it 'sets the dashboard_url on the instance' do
        client.provision(instance)

        expect(instance.dashboard_url).to eq('foo')
      end

      it 'defaults the state to "available"' do
        client.provision(instance)

        expect(instance.state).to eq('available')
      end

      it 'leaves the description blank' do
        client.provision(instance)

        expect(instance.state_description).to eq('')
      end

      it 'DEPRECATED, maintain for database not null contraint: sets the credentials on the instance' do
        client.provision(instance)

        expect(instance.credentials).to eq({})
      end

      context 'when the broker returns no state or the state is created, or available' do
        let(:response_data) do
          {
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          client.provision(instance)

          expect(instance.state).to eq('available')
          expect(instance.state_description).to eq('')
        end

        it 'does not enqueue a polling job' do
          client.provision(instance)
          expect(state_poller).to_not have_received(:poll_service_instance_state)
        end
      end

      context 'when the broker returns the state as creating' do
        let(:response_data) do
          {
            state: 'creating',
            state_description: '10% done'
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          client.provision(instance)

          expect(instance.state).to eq('creating')
          expect(instance.state_description).to eq('10% done')
        end

        it 'enqueues a polling job' do
          client.provision(instance)
          expect(state_poller).to have_received(:poll_service_instance_state).with(client_attrs, instance)
        end
      end

      context 'when the broker returns the state as failed' do
        let(:response_data) do
          {
            state: 'failed',
            state_description: '100% failed'
          }
        end

        it 'return immediately with the broker response' do
          client = Client.new(client_attrs.merge(accepts_incomplete: true))
          client.provision(instance)

          expect(instance.state).to eq('failed')
          expect(instance.state_description).to eq('100% failed')
        end

        it 'does not enqueue a polling job' do
          client.provision(instance)
          expect(state_poller).to_not have_received(:poll_service_instance_state)
        end
      end

      context 'when provision fails' do
        let(:uri) { 'some-uri.com/v2/service_instances/some-guid' }
        let(:response) { double(:response, body: nil, message: nil) }

        context 'due to an http client error' do
          let(:http_client) { double(:http_client) }

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
          let(:response_parser) { double(:response_parser) }

          before do
            allow(response_parser).to receive(:parse).and_raise(error)
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
        end
      end
    end

    describe '#fetch_service_instance_state' do
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.new(
          service_plan: plan,
          space: space
        )
      end

      let(:response_data) do
        {
          'dashboard_url' => 'bar',
          'state' => 'created',
          'state_description' => '100% created'
        }
      end

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { double('response') }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:get).and_return(response)

        allow(response).to receive(:body).and_return(response_body)
        allow(response).to receive(:code).and_return(code)
        allow(response).to receive(:message).and_return(message)
      end

      it 'makes a put request with correct path' do
        client.fetch_service_instance_state(instance)

        expect(http_client).to have_received(:get).
          with("/v2/service_instances/#{instance.guid}")
      end

      it 'returns the instance given with new state values' do
        returned_instance = client.fetch_service_instance_state(instance)

        expect(returned_instance).to be(instance)

        expect(returned_instance.dashboard_url).to eq('bar')
        expect(returned_instance.state).to eq('created')
        expect(returned_instance.state_description).to eq('100% created')
      end
    end

    describe '#update_service_plan' do
      let(:old_plan) { VCAP::CloudController::ServicePlan.make }
      let(:new_plan) { VCAP::CloudController::ServicePlan.make }

      let(:space) { VCAP::CloudController::Space.make }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.new(
          service_plan: old_plan,
          space: space
        )
      end

      let(:service_plan_guid) { new_plan.guid }

      let(:path) { "/v2/service_instances/#{instance.guid}/" }
      let(:code) { 200 }
      let(:message) { 'OK' }
      let(:response_data) { '{}' }

      before do
        allow(http_client).to receive(:patch).and_return(double('response', code: code, body: response_data, message: message))
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

      describe 'error handling' do
        describe 'non-standard errors' do
          before do
            fake_response = double('response', code: status_code, body: body)
            allow(http_client).to receive(:patch).and_return(fake_response)
          end

          context 'when the broker returns a 422' do
            let(:status_code) { '422' }
            let(:body) { { description: 'cannot update to this plan' }.to_json }
            it 'raises a ServiceBrokerRequestRejected error' do
              expect { client.update_service_plan(instance, new_plan) }.to raise_error(
                Errors::ServiceBrokerRequestRejected, /cannot update to this plan/
              )
            end
          end
        end
      end
    end

    describe '#bind' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:app) { VCAP::CloudController::App.make }
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
      let(:response) { double('response') }
      let(:response_body) { response_data.to_json }
      let(:code) { '201' }
      let(:message) { 'Created' }

      before do
        allow(http_client).to receive(:put).and_return(response)

        allow(response).to receive(:body).and_return(response_body)
        allow(response).to receive(:code).and_return(code)
        allow(response).to receive(:message).and_return(message)
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
               {
            plan_id:    binding.service_plan.broker_provided_id,
            service_id: binding.service.broker_provided_id,
            app_guid:   binding.app_guid
          }
              )
      end

      it 'sets the credentials on the binding' do
        client.bind(binding)

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
          client.bind(binding)
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
        let(:response) { double(:response, body: nil, message: nil) }

        context 'due to an http client error' do
          let(:http_client) { double(:http_client) }

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
          let(:response_parser) { double(:response_parser) }

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
      let(:response) { double('response') }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)

        allow(response).to receive(:body).and_return(response_body)
        allow(response).to receive(:code).and_return(code)
        allow(response).to receive(:message).and_return(message)
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

      context 'DEPRECATED: the broker should not return 204, but we still support the case when it does' do
        let(:code) { '204' }
        let(:response_body) { 'invalid json' }

        it 'does not break' do
          expect { client.unbind(binding) }.to_not raise_error
        end
      end
    end

    describe '#deprovision' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }

      let(:response_data) { {} }

      let(:path) { "/v2/service_instances/#{instance.guid}" }
      let(:response) { double('response') }
      let(:response_body) { response_data.to_json }
      let(:code) { '200' }
      let(:message) { 'OK' }

      before do
        allow(http_client).to receive(:delete).and_return(response)

        allow(response).to receive(:body).and_return(response_body)
        allow(response).to receive(:code).and_return(code)
        allow(response).to receive(:message).and_return(message)
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
