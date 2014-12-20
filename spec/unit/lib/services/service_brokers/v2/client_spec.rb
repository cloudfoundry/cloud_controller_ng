require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  describe ServiceBrokerBadResponse do
    let(:uri) { 'http://www.example.com/' }
    let(:response) { double(code: 500, message: 'Internal Server Error', body: response_body) }
    let(:method) { 'PUT' }

    context 'with a description in the body' do
      let(:response_body) do
        {
          'description' => 'Some error text'
        }.to_json
      end

      it 'generates the correct hash' do
        exception = described_class.new(uri, method, response)
        exception.set_backtrace(['/foo:1', '/bar:2'])

        expect(exception.to_h).to eq({
          'description' => "Service broker error: Some error text",
          'backtrace' => ['/foo:1', '/bar:2'],
          "http" => {
            "status" => 500,
            "uri" => uri,
            "method" => "PUT"
          },
          'source' => {
            'description' => 'Some error text'
          }
        })
      end

    end

    context 'without a description in the body' do
      let(:response_body) do
        {'foo' => 'bar'}.to_json
      end
      it 'generates the correct hash' do
        exception = described_class.new(uri, method, response)
        exception.set_backtrace(['/foo:1', '/bar:2'])

        expect(exception.to_h).to eq({
          'description' => "The service broker API returned an error from http://www.example.com/: 500 Internal Server Error",
          'backtrace' => ['/foo:1', '/bar:2'],
          "http" => {
            "status" => 500,
            "uri" => uri,
            "method" => "PUT"
          },
          'source' => {'foo' => 'bar'}
        })
      end

    end

  end

  describe 'the remaining ServiceBrokers::V2 exceptions' do
    let(:uri) { 'http://uri.example.com' }
    let(:method) { 'POST' }
    let(:error) { StandardError.new }

    describe ServiceBrokerResponseMalformed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 200, reason: 'OK', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerResponseMalformed.new(uri, method, response)
        expect(exception.message).to eq("The service broker response was not understood")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerApiAuthenticationFailed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 401, reason: 'Auth Error', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerApiAuthenticationFailed.new(uri, method, response)
        expect(exception.message).to eq("Authentication failed for the service broker API. Double-check that the username and password are correct: #{uri}")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerConflict do
      let(:response_body) { '{"message": "error message"}' }
      let(:response) { double(code: 409, reason: 'Conflict', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        expect(exception.message).to eq("error message")
        expect(exception.uri).to eq(uri)
        expect(exception.method).to eq(method)
        expect(exception.source).to eq(MultiJson.load(response.body))
      end

      it "has a response_code of 409" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        expect(exception.response_code).to eq(409)
      end

      context "when the response body has no message" do
        let(:response_body) { '{"description": "error description"}' }

        context "and there is a description field" do
            it "initializes the base class correctly" do
              exception = ServiceBrokerConflict.new(uri, method, response)
              expect(exception.message).to eq("error description")
              expect(exception.uri).to eq(uri)
              expect(exception.method).to eq(method)
              expect(exception.source).to eq(MultiJson.load(response.body))
            end
        end

        context "and there is no description field" do
          let(:response_body) { '{"field": "value"}' }

            it "initializes the base class correctly" do
              exception = ServiceBrokerConflict.new(uri, method, response)
              expect(exception.message).to eq("Resource conflict: #{uri}")
              expect(exception.uri).to eq(uri)
              expect(exception.method).to eq(method)
              expect(exception.source).to eq(MultiJson.load(response.body))
            end
          end
      end

      context "when the body is not JSON-parsable" do
        let(:response_body) { 'foo' }

        it "initializes the base class correctly" do
          exception = ServiceBrokerConflict.new(uri, method, response)
          expect(exception.message).to eq("Resource conflict: #{uri}")
          expect(exception.uri).to eq(uri)
          expect(exception.method).to eq(method)
          expect(exception.source).to eq(response.body)
        end
      end
    end
  end

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

    before do
      allow(HttpClient).to receive(:new).
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
            expect(error_hash.fetch('description')).to eq("The service broker API returned an error from #{service_broker.broker_url}#{path}: 500 Internal Server Error")
            expect(error_hash.fetch('source')).to include({'foo' => 'bar'})
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
            expect(error_hash.fetch('description')).
              to eq("Authentication failed for the service broker API. Double-check that the username and password are correct: #{service_broker.broker_url}#{path}")
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
        allow(http_client).to receive(:delete).and_return(response)

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

      context 'when provision fails' do
        before do
          allow(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).to receive(:deprovision)
        end

        context 'and http client response is 408' do
          before do
            allow(response).to receive(:code).and_return('408', '200')
          end

          it 'raises ServiceBrokerApiTimeout and deprovisions' do
            expect {
              client.provision(instance)
            }.to raise_error(ServiceBrokerApiTimeout)

            expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                   to have_received(:deprovision).with(client_attrs, instance)
          end
        end

        context 'and http client response is 5xx' do
          context 'and http error code is 500' do
            before do
              allow(response).to receive(:code).and_return('500', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end

          context 'and http error code is 501' do
            before do
              allow(response).to receive(:code).and_return('501', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end

          context 'and http error code is 502' do
            before do
              allow(response).to receive(:code).and_return('502', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end

          context 'and http error code is 503' do
            before do
              allow(response).to receive(:code).and_return('503', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end

          context 'and http error code is 504' do
            before do
              allow(response).to receive(:code).and_return('504', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end

          context 'and http error code is 505' do
            before do
              allow(response).to receive(:code).and_return('505', '200')
            end

            it 'raises ServiceBrokerBadResponse and deprovisions' do
              expect {
                  client.provision(instance)
              }.to raise_error(ServiceBrokerBadResponse)

              expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                     to have_received(:deprovision).
                                     with(client_attrs, instance)
            end
          end
        end
      end

      context 'when provision takes longer than broker configured timeout' do
        before do
          allow(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).to receive(:deprovision)
        end

        context 'when http_client make request fails with ServiceBrokerApiTimeout' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise ServiceBrokerApiTimeout.new(path, :put, Timeout::Error.new(message))
            end
          end

          it 'deprovisions the instance' do
            expect {
              client.provision(instance)
            }.to raise_error(ServiceBrokerApiTimeout)

            expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceDeprovisioner).
                                   to have_received(:deprovision).
                                   with(client_attrs, instance)
          end
        end

        context 'when http_client make request fails with ServiceBrokerApiUnreachable' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise ServiceBrokerApiUnreachable.new(path, :put, Errno::ECONNREFUSED)
            end
          end

          it 'fails' do
            expect {
              client.provision(instance)
            }.to raise_error(ServiceBrokerApiUnreachable)
          end
        end

        context 'when http_client make request fails with HttpRequestError' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise HttpRequestError.new(message, path, :put, Exception.new(message))
            end
          end

          it 'fails' do
            expect {
              client.provision(instance)
            }.to raise_error(HttpRequestError)
          end
        end
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

      it 'makes a patch request with the new service plan' do
        allow(http_client).to receive(:patch).and_return(double('response', code: 200, body: '{}'))
        client.update_service_plan(instance, new_plan)

        expect(http_client).to have_received(:patch).with(
          anything(),
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
        allow(http_client).to receive(:patch).and_return(double('response', code: 200, body: '{}'))

        client.update_service_plan(instance, new_plan)

        expect(http_client).to have_received(:patch).with(path, anything())
      end

      describe 'error handling' do
        before do
          fake_response = double('response', code: status_code, body: body)
          allow(http_client).to receive(:patch).and_return(fake_response)
        end

        context 'when the broker returns a 400' do
          let(:status_code) { '400' }
          let(:body) { { description: 'the request was malformed' }.to_json }
          it 'raises a ServiceBrokerBadResponse error' do
            expect{ client.update_service_plan(instance, new_plan) }.to raise_error(
              ServiceBrokerBadResponse, /the request was malformed/
            )
          end
        end

        context 'when the broker returns a 404' do
          let(:status_code) { '404' }
          let(:body) { { description: 'service instance not found'}.to_json }
          it 'raises a ServiceBrokerBadRequest error' do
            expect{ client.update_service_plan(instance, new_plan) }.to raise_error(
              ServiceBrokerBadResponse, /service instance not found/
            )
          end
        end

        context 'when the broker returns a 422' do
          let(:status_code) { '422' }
          let(:body) { { description: 'cannot update to this plan' }.to_json }
          it 'raises a ServiceBrokerBadResponse error' do
            expect{ client.update_service_plan(instance, new_plan) }.to raise_error(
              ServiceBrokerBadResponse, /cannot update to this plan/
            )
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

      context 'with a syslog drain url' do

        let(:response_data) do
          {
              'credentials' => { },
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
              'credentials' => { }
          }
        end

        it 'does not set the syslog_drain_url on the binding' do
          client.bind(binding)
          expect(binding.syslog_drain_url).to_not be
        end

      end

      context 'when bind takes longer than broker configured timeout' do
        let(:binding) do
          VCAP::CloudController::ServiceBinding.make(
            binding_options: { 'this' => 'that' }
          )
        end

        before do
          allow(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceUnbinder).to receive(:unbind)
        end

        context 'when http_client make request fails with ServiceBrokerApiTimeout' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise ServiceBrokerApiTimeout.new(path, :put, Timeout::Error.new(message))
            end
          end

          it 'unbinds the binding' do
            expect {
              client.bind(binding)
            }.to raise_error(ServiceBrokerApiTimeout)

            expect(VCAP::CloudController::ServiceBrokers::V2::ServiceInstanceUnbinder).
                                   to have_received(:unbind).
                                   with(client_attrs, binding)
          end
        end

        context 'when http_client make request fails with ServiceBrokerApiUnreachable' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise ServiceBrokerApiUnreachable.new(path, :put, Errno::ECONNREFUSED)
            end
          end

          it 'fails' do
            expect {
              client.bind(binding)
            }.to raise_error(ServiceBrokerApiUnreachable)
          end
        end

        context 'when http_client make request fails with HttpRequestError' do
          before do
            allow(http_client).to receive(:put) do |path, message|
              raise HttpRequestError.new(message, path, :put, Exception.new(message))
            end
          end

          it 'fails' do
            expect {
              client.bind(binding)
            }.to raise_error(HttpRequestError)
          end
        end
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
