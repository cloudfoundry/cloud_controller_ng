require "spec_helper"

module VCAP::CloudController
  describe ServiceBrokerClient do
    let(:endpoint_base) { 'http://example.com' }
    let(:request_id) { 'req-id' }
    let(:token) { 'sometoken' }
    let(:client) { ServiceBrokerClient.new(endpoint_base, token) }

    # we use the catalog_response in both the #catalog spec and the error conditions specs
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

    before do
      stub_request(:any, endpoint_base)
      VCAP::Request.stub(:current_id).and_return(request_id)
    end

    describe "#catalog" do
      it 'fetches the broker catalog' do
        stub_request(:get, "http://cc:sometoken@example.com/v2/catalog").
          with(headers: { 'X-VCAP-Request-ID' => request_id }).
          to_return(body: catalog_response.to_json)

        catalog = client.catalog

        expect(catalog).to eq(catalog_response)
      end
    end

    describe "#provision" do
      let(:reference_id) { 'ref_id' }
      let(:broker_service_instance_id) { 'broker_created_id' }

      let(:expected_request_body) do
        {
          service_id: service_id,
          plan_id: plan_id,
          reference_id: reference_id,
        }.to_json
      end
      let(:expected_response_body) do
        {
          id: broker_service_instance_id
        }.to_json
      end

      it 'calls the provision endpoint' do
        stub_request(:post, "http://cc:sometoken@example.com/v2/service_instances").
          with(body: expected_request_body, headers: { 'X-VCAP-Request-ID' => request_id }).
          to_return(body: expected_response_body)

        result = client.provision(service_id, plan_id, reference_id)

        expect(result['id']).to eq(broker_service_instance_id)
      end

      context 'the reference_id is already in use' do
        it 'raises ServiceBrokerConflict' do
          stub_request(:post, "http://cc:sometoken@example.com/v2/service_instances").
            to_return(status: 409)  # 409 is CONFLICT

          expect { client.provision(service_id, plan_id, reference_id) }.to raise_error(VCAP::Errors::ServiceBrokerConflict)
        end
      end
    end

    describe "error conditions" do
      let(:broker_catalog_url) { "http://cc:sometoken@example.com/v2/catalog" }

      context 'when the API is not reachable' do
        context 'because the host could not be resolved' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(SocketError)
          end

          it 'should raise an unreachable error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server connection attempt timed out' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::ConnectTimeoutError)
          end

          it 'should raise an unreachable error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'should raise an unreachable error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the server gave up' do
          before do
            # We have to instantiate the error object to keep WebMock from initializing
            # it with a String message. KeepAliveDisconnected actually takes an optional
            # Session object, which later HTTPClient code attempts to use.
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::KeepAliveDisconnected.new)
          end

          it 'should raise a timeout error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end

        context 'because the client gave up' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::ReceiveTimeoutError)
          end

          it 'should raise a timeout error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end
      end

      context 'when the API returns an invalid response' do
        context 'because of an unexpected status code' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 400, body: catalog_response.to_json)
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerResponseMalformed)
          end
        end

        context 'because of an unexpected body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: '[]')
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerResponseMalformed)
          end
        end

        context 'because of an invalid JSON body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: 'invalid')
          end

          it 'should raise an invalid response error' do
            expect {
              client.catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerResponseMalformed)
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
          }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiAuthenticationFailed)
        end
      end
    end
  end
end
