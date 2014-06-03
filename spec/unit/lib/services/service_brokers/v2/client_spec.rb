require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  describe Client do
    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

    subject(:client) do
      Client.new(
        url: service_broker.broker_url,
        auth_username: service_broker.auth_username,
        auth_password: service_broker.auth_password,
      )
    end

    let(:http_client) { double('http_client') }

    before do
      HttpClient.stub(:new).
        with(url: service_broker.broker_url, auth_username: service_broker.auth_username, auth_password: service_broker.auth_password).
        and_return(http_client)

      allow(http_client).to receive(:url).and_return(service_broker.broker_url)
    end

    shared_examples 'handles standard error conditions' do
      context 'when the API returns an error code' do
        let(:response_data) {{ 'foo' => 'bar' }}
        let(:code) { '500' }
        let(:message) { 'Internal Server Error' }

        it 'should raise a ServiceBrokerBadResponse' do
          expect {
            operation
          }.to raise_error { |e|
            expect(e).to be_a(ServiceBrokerBadResponse)
            error_hash = e.to_h
            error_hash.fetch('description').should eq("The service broker API returned an error from #{service_broker.broker_url}#{path}: 500 Internal Server Error")
            error_hash.fetch('source').should include({'foo' => 'bar'})
          }
        end
      end

      context 'when the API returns an invalid response' do
        context 'because of an unexpected status code' do
          let(:code) { '404' }
          let(:message) { 'Not Found' }

          it 'should raise an invalid response error' do
            expect {
              operation
            }.to raise_error(
                   ServiceBrokerBadResponse,
                   "The service broker API returned an error from #{service_broker.broker_url}#{path}: 404 Not Found"
                 )
          end
        end

        context 'because of a response that does not return a valid hash' do
          let(:response_data) { [] }

          it 'should raise an invalid response error' do
            expect {
              operation
            }.to raise_error(ServiceBrokerResponseMalformed)
          end
        end

        context 'because of an invalid JSON body' do
          let(:response_data) { 'invalid' }

          it 'should raise an invalid response error' do
            expect {
              operation
            }.to raise_error(ServiceBrokerResponseMalformed)
          end
        end
      end

      context 'when the API cannot authenticate the client' do
        let(:code) { '401' }

        it 'should raise an authentication error' do
          expect {
            operation
          }.to raise_error { |e|
            expect(e).to be_a(ServiceBrokerApiAuthenticationFailed)
            error_hash = e.to_h
            error_hash.fetch('description').
              should eq("Authentication failed for the service broker API. Double-check that the username and password are correct: #{service_broker.broker_url}#{path}")
          }
        end
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

      describe 'handling errors' do
        it_behaves_like 'handles standard error conditions' do
          let(:operation) { client.catalog }
        end
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

      let(:path) { "/v2/service_instances/#{instance.guid}" }
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
        client.provision(instance)

        expect(http_client).to have_received(:put).
                                 with("/v2/service_instances/#{instance.guid}", anything())
      end

      it 'makes a put request with correct message' do
        client.provision(instance)

        expect(http_client).to have_received(:put).
                                 with(anything(),
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

      it 'DEPRECATED, maintain for database not null contraint: sets the credentials on the instance' do
        client.provision(instance)

        expect(instance.credentials).to eq({})
      end

      describe 'error handling' do
        context 'the instance_id is already in use' do
          let(:code) { '409' }

          it 'raises ServiceBrokerConflict' do
            expect {
              client.provision(instance)
            }.to raise_error(ServiceBrokerConflict)
          end
        end

        it_behaves_like 'handles standard error conditions' do
          let(:operation) { client.provision(instance) }
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
                                 with("/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}", anything())
      end

      it 'makes a put request with correct message' do
        client.bind(binding)

        expect(http_client).to have_received(:put).
                                 with(anything(),
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

      describe 'error handling' do
        context 'the binding id is already in use' do
          let(:code) { '409' }

          it 'raises ServiceBrokerConflict' do
            expect {
              client.bind(binding)
            }.to raise_error(ServiceBrokerConflict)
          end
        end

        it_behaves_like 'handles standard error conditions' do
          let(:operation) { client.bind(binding) }
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
                                 with("/v2/service_instances/#{binding.service_instance.guid}/service_bindings/#{binding.guid}", anything())
      end

      it 'makes a delete request with correct message' do
        client.unbind(binding)

        expect(http_client).to have_received(:delete).
                                 with(anything(),
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

      describe 'handling errors' do
        context 'when the API returns 410' do
          let(:code) { '410' }

          it 'should swallow the error' do
            expect(client.unbind(binding)).to be_nil
          end
        end

        it_behaves_like 'handles standard error conditions' do
          let(:operation) { client.unbind(binding) }
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
                                 with("/v2/service_instances/#{instance.guid}", anything())
      end

      it 'makes a delete request with correct message' do
        client.deprovision(instance)

        expect(http_client).to have_received(:delete).
                                 with(anything(),
                                      {
                                        service_id: instance.service.broker_provided_id,
                                        plan_id:    instance.service_plan.broker_provided_id
                                      }
                               )
      end

      describe 'handling errors' do
        context 'when the API returns 410' do
          let(:code) { '410' }

          it 'should swallow the error' do
            expect(client.deprovision(instance)).to be_nil
          end
        end

        it_behaves_like 'handles standard error conditions' do
          let(:operation) { client.deprovision(instance) }
        end
      end
    end
  end

end
