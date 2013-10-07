require 'spec_helper'

module VCAP::CloudController::ServiceBroker::V2

  describe ServiceBrokerBadResponse do
    let(:uri) { 'http://www.example.com/' }
    let(:response_body) do
      { 'foo' => 'bar' }.to_json
    end
    let(:response) { double(code: 500, message: 'Internal Server Error', body: response_body) }
    let(:method) { 'PUT' }

    it 'generates the correct hash' do
      exception = described_class.new(uri, method, response)
      exception.set_backtrace(['/foo:1', '/bar:2'])

      expect(exception.to_h).to eq({
        'description' => "The service broker API returned an error from http://www.example.com/: 500 Internal Server Error",
        'types' => ["ServiceBrokerBadResponse", "HttpResponseError"],
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

  describe ServiceBrokerApiUnreachable do
    let(:uri) { 'http://www.example.com/' }
    let(:error) { SocketError.new('some message') }

    before do
      error.set_backtrace(['/socketerror:1', '/backtrace:2'])
    end

    it 'generates the correct hash' do
      exception = ServiceBrokerApiUnreachable.new(uri, 'PUT', error)
      exception.set_backtrace(['/generatedexception:3', '/backtrace:4'])

      expect(exception.to_h).to eq({
        'description' => 'The service broker API could not be reached: http://www.example.com/',
        'types' => [
          'ServiceBrokerApiUnreachable',
          'HttpRequestError',
        ],
        'backtrace' => ['/generatedexception:3', '/backtrace:4'],
        'http' => {
          'uri' => uri,
          'method' => 'PUT'
        },
        'source' => {
          'description' => error.message,
          'types' => ['SocketError'],
          'backtrace' => ['/socketerror:1', '/backtrace:2']
          }
      })
    end
  end

  describe 'the remaining ServiceBroker::V2 exceptions' do
    let(:uri) { 'http://uri.example.com' }
    let(:method) { 'POST' }
    let(:error) { StandardError.new }

    describe ServiceBrokerApiTimeout do
      it "initializes the base class correctly" do
        exception = ServiceBrokerApiTimeout.new(uri, method, error)
        expect(exception.message).to eq("The service broker API timed out: #{uri}")
        expect(exception.uri).to be(uri)
        expect(exception.method).to be(method)
        expect(exception.source).to be(error)
      end
    end

    describe ServiceBrokerResponseMalformed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 200, reason: 'OK', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerResponseMalformed.new(uri, method, response)
        expect(exception.message).to eq("The service broker response was not understood")
        expect(exception.uri).to be(uri)
        expect(exception.method).to be(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerApiAuthenticationFailed do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 401, reason: 'Auth Error', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerApiAuthenticationFailed.new(uri, method, response)
        expect(exception.message).to eq("Authentication failed for the service broker API. Double-check that the token is correct: #{uri}")
        expect(exception.uri).to be(uri)
        expect(exception.method).to be(method)
        expect(exception.source).to be(response.body)
      end
    end

    describe ServiceBrokerConflict do
      let(:response_body) { 'foo' }
      let(:response) { double(code: 409, reason: 'Conflict', body: response_body) }

      it "initializes the base class correctly" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        expect(exception.message).to eq("Resource already exists: #{uri}")
        expect(exception.uri).to be(uri)
        expect(exception.method).to be(method)
        expect(exception.source).to be(response.body)
      end

      it "has a response_code of 409" do
        exception = ServiceBrokerConflict.new(uri, method, response)
        expect(exception.response_code).to eq(409)
      end
    end
  end

  describe HttpClient do
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }
    let(:request_id) { Sham.guid }
    let(:expected_request_headers) do
      {
        'X-VCAP-Request-ID' => request_id,
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    end

    subject(:client) do
      HttpClient.new(
        url: 'http://broker.example.com',
        auth_username: auth_username,
        auth_password: auth_password
      )
    end

    before do
      VCAP::Request.stub(:current_id).and_return(request_id)
    end

    describe '#catalog' do
      let(:service_id) { Sham.guid }
      let(:service_name) { Sham.name }
      let(:service_description) { Sham.description }
      let(:plan_id) { Sham.guid }
      let(:plan_name) { Sham.name }
      let(:plan_description) { Sham.description }
      let(:catalog_response) do
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

      it 'sends a GET to /v2/catalog' do
        stub_request(:get, "http://#{auth_username}:#{auth_password}@broker.example.com/v2/catalog").
          with(headers: expected_request_headers).
          to_return(body: catalog_response.to_json)

        catalog = client.catalog

        expect(catalog).to eq(catalog_response)
      end
    end

    describe '#provision' do
      let(:instance_id) { Sham.guid }
      let(:plan_id) { Sham.guid }

      let(:expected_request_body) do
        {
          plan_id: plan_id,
          organization_guid: "org-guid",
          space_guid: "space-guid"
        }.to_json
      end

      let(:expected_response_body) do
        {
          dashboard_url: 'dashboard url'
        }.to_json
      end

      it 'sends a PUT to /v2/service_instances/:id' do
        stub_request(:put, "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_instances/#{instance_id}").
          with(body: expected_request_body, headers: expected_request_headers).
          to_return(status: 201, body: expected_response_body)

        response = client.provision(instance_id, plan_id, "org-guid", "space-guid")

        expect(response.fetch('dashboard_url')).to eq('dashboard url')
      end

      context 'the reference_id is already in use' do
        it 'raises ServiceBrokerConflict' do
          stub_request(:put, "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_instances/#{instance_id}").
            to_return(status: 409)  # 409 is CONFLICT

          expect { client.provision(instance_id, plan_id, "org-guid", "space-guid") }.
            to raise_error(ServiceBrokerConflict)
        end
      end
    end

    describe '#bind' do
      let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
      let(:service_instance) { service_binding.service_instance }

      let(:bind_url) { "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_bindings/#{service_binding.guid}" }

      before do
        @request = stub_request(:put, bind_url).with(headers: expected_request_headers).to_return(
          body: {
            credentials: {user: 'admin', pass: 'secret'}
          }.to_json
        )
      end

      it 'sends a PUT to /v2/service_bindings/:id' do
        client.bind(service_binding.guid, service_instance.guid)

        expect(@request.with { |request|
          request_body = Yajl::Parser.parse(request.body)
          expect(request_body.fetch('service_instance_id')).to eq(service_binding.service_instance.guid)
        }).to have_been_made
      end

      it 'returns the response body' do
        response = client.bind(service_binding.guid, service_instance.guid)

        expect(response).to eq('credentials' => {'user' => 'admin', 'pass' => 'secret'})
      end
    end

    describe '#unbind' do
      let(:service_binding) { VCAP::CloudController::ServiceBinding.make }
      let(:bind_url) { "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_bindings/#{service_binding.guid}" }
      before do
        @request = stub_request(:delete, bind_url).with(headers: expected_request_headers).to_return(status: 204)
      end

      it 'sends a DELETE to /v2/service_bindings/:id' do
        client.unbind(service_binding.guid)
        @request.should have_been_requested
      end
    end

    describe '#deprovision' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:instance_url) { "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_instances/#{instance.guid}" }
      before do
        @request = stub_request(:delete, instance_url).with(headers: expected_request_headers).to_return(status: 204)
      end

      it 'sends a DELETE to /v2/service_instances/:id' do
        client.deprovision(instance.guid)
        @request.should have_been_requested
      end
    end

    describe 'error conditions' do
      let(:broker_catalog_url) { "http://#{auth_username}:#{auth_password}@broker.example.com/v2/catalog" }

      context 'when the API is not reachable' do
        context 'because the host could not be resolved' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(SocketError)
          end

          it 'should raise an unreachable error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'should raise an unreachable error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the client gave up' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(Timeout::Error)
          end

          it 'should raise a timeout error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerApiTimeout)
          end
        end
      end

      context 'when the API returns an error code' do
        let(:error_response) { { 'foo' => 'bar' } }

        before do
          stub_request(:get, broker_catalog_url).to_return(
            status: [500, 'Internal Server Error'], body: error_response.to_json
          )
        end

        it 'should raise a ServiceBrokerBadResponse' do
          expect {
            client.catalog
          }.to raise_error { |e|
            expect(e).to be_a(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerBadResponse)
            error_hash = e.to_h
            error_hash.fetch('description').should eq('The service broker API returned an error from http://broker.example.com/v2/catalog: 500 Internal Server Error')
            error_hash.fetch('types').should include('ServiceBrokerBadResponse', 'HttpResponseError')
            error_hash.fetch('source').should include({ 'foo' => 'bar' })
          }
        end
      end

      context 'when the API returns an invalid response' do
        context 'because of an unexpected status code' do
          let(:catalog_response) { {'services' => []} }

          before do
            stub_request(:get, broker_catalog_url).to_return(
              status: [404, 'Not Found'], body: catalog_response.to_json
            )
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(
              VCAP::CloudController::ServiceBroker::V2::ServiceBrokerBadResponse,
              'The service broker API returned an error from http://broker.example.com/v2/catalog: 404 Not Found'
            )
          end
        end

        context 'because of an unexpected body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: '[]')
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerResponseMalformed)
          end
        end

        context 'because of an invalid JSON body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: 'invalid')
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerResponseMalformed)
          end
        end
      end

      context 'when the API cannot authenticate the client' do
        before do
          stub_request(:get, broker_catalog_url).to_return(status: 401)
        end

        it 'should raise an authentication error' do
          expect {
            client.catalog
          }.to raise_error{ |e|
            expect(e).to be_a(VCAP::CloudController::ServiceBroker::V2::ServiceBrokerApiAuthenticationFailed)
            error_hash = e.to_h
            error_hash.fetch('description').
              should eq("Authentication failed for the service broker API. Double-check that the token is correct: http://broker.example.com/v2/catalog")
          }
        end
      end

      context 'when the API returns 410 to a DELETE request' do
        before do
          @stub = stub_request(:delete, "http://#{auth_username}:#{auth_password}@broker.example.com/v2/service_instances/asdf").to_return(
            status: [410, 'Gone']
          )
        end

        it 'should swallow the error' do
          expect(client.deprovision('asdf')).to be_nil
          @stub.should have_been_requested
        end
      end
    end
  end
end
