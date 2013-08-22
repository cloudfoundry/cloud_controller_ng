require 'spec_helper'

module VCAP::CloudController
  describe ServiceBrokersController, :services, type: :controller do
    let(:headers) { json_headers(headers_for(admin_user, admin_scope: true)) }

    let(:non_admin_headers) do
      user = VCAP::CloudController::Models::User.make(admin: false)
      json_headers(headers_for(user))
    end

    before do
      reset_database

      Steno.init(Steno::Config.new(
        :default_log_level => "debug2",
        :sinks => [Steno::Sink::IO.for_file("/tmp/cloud_controller_test.log")]
      ))
    end

    describe 'POST /v2/service_brokers' do
      let(:name) { Sham.name }
      let(:broker_url) { 'http://cf-service-broker.example.com' }
      let(:broker_api_url) { "http://cc:#{token}@cf-service-broker.example.com/v3" }
      let(:token) { 'abc123' }

      let(:body_hash) do
        {
          name: name,
          broker_url: broker_url,
          token: token
        }
      end
      let(:body) { body_hash.to_json }

      before do
        stub_request(:get, broker_api_url).to_return(status: 200, body: '["OK"]')
      end

      it 'returns a 201 status' do
        post '/v2/service_brokers', body, headers

        last_response.status.should == 201
      end

      it 'creates a service broker' do
        expect {
          post '/v2/service_brokers', body, headers
        }.to change(Models::ServiceBroker, :count).by(1)

        broker = Models::ServiceBroker.last
        broker.name.should == name
        broker.broker_url.should == broker_url
        broker.token.should == token
      end

      it 'omits the token from the response' do
        post '/v2/service_brokers', body, headers

        metadata = decoded_response.fetch('metadata')
        entity = decoded_response.fetch('entity')

        metadata.fetch('guid').should == Models::ServiceBroker.last.guid
        entity.should_not have_key('token')
      end

      it 'includes the url of the resource in the response metadata' do
        post '/v2/service_brokers', body, headers

        metadata = decoded_response.fetch('metadata')
        metadata.fetch('url').should == "/v2/service_brokers/#{metadata.fetch('guid')}"
      end

      it 'includes the broker name in the response entity' do
        post '/v2/service_brokers', body, headers

        metadata = decoded_response.fetch('entity')
        metadata.fetch('name').should == name
      end

      it 'includes the broker url in the response entity' do
        post '/v2/service_brokers', body, headers

        metadata = decoded_response.fetch('entity')
        metadata.fetch('broker_url').should == broker_url
      end

      it "returns an error if the broker name is not present" do
        body = {
          broker_url: broker_url,
          token: token
        }.to_json

        post '/v2/service_brokers', body, headers

        last_response.should be_bad_request
        decoded_response.fetch('code').should == 270001
        decoded_response.fetch('description').should =~ /name presence/
      end

      it "returns an error if the broker url is not present" do
        body = {
          name: name,
          token: token
        }.to_json

        post '/v2/service_brokers', body, headers

        last_response.should be_bad_request
        decoded_response.fetch('code').should == 270001
        decoded_response.fetch('description').should =~ /broker_url presence/
      end

      it "returns an error if the token is not present" do
        body = {
          name: name,
          broker_url: broker_url
        }.to_json

        post '/v2/service_brokers', body, headers

        last_response.should be_bad_request
        decoded_response.fetch('code').should == 270001
        decoded_response.fetch('description').should =~ /token presence/
      end

      it "returns an error if the broker name is not unique" do
        Models::ServiceBroker.make(name: name)

        post '/v2/service_brokers', body, headers

        last_response.should be_bad_request
        decoded_response.fetch('code').should == 270002
        decoded_response.fetch('description').should == "The service broker name is taken: #{name}"
      end

      it "returns an error if the broker url is not unique" do
        Models::ServiceBroker.make(broker_url: broker_url)

        post '/v2/service_brokers', body, headers

        last_response.should be_bad_request

        decoded_response.fetch('code').should == 270003
        decoded_response.fetch('description').should == "The service broker url is taken: #{broker_url}"
      end

      it 'includes a location header for the resource' do
        post '/v2/service_brokers', body, headers

        headers = last_response.original_headers
        metadata = decoded_response.fetch('metadata')
        headers.fetch('Location').should == "/v2/service_brokers/#{metadata.fetch('guid')}"
      end

      it 'does not set fields that are unmodifiable' do
        body_with_guid = body_hash.merge(guid: 'mycustomguid').to_json
        post '/v2/service_brokers', body_with_guid, headers
        Models::ServiceBroker.order(:id).last.guid.should_not == 'mycustomguid'
      end

      context 'when the broker API check fails' do
        before do
          stub_request(:get, broker_api_url).to_raise(SocketError)
        end

        it 'returns an error' do
          error = Errors::ServiceBrokerApiUnreachable.new(broker_url)

          post '/v2/service_brokers', body, headers

          last_response.status.should == error.response_code
          decoded_response.fetch('code').should == error.error_code
          decoded_response.fetch('description').should == error.message
        end

        it 'does not create a broker record' do
          expect {
            post '/v2/service_brokers', body, headers
          }.to_not change(Models::ServiceBroker, :count)
        end
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          post '/v2/service_brokers', body, non_admin_headers
          expect(last_response).to be_forbidden
        end

        it 'returns 401 for logged-out users' do
          post '/v2/service_brokers', body
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe "GET /v2/service_brokers" do
      let!(:broker) { Models::ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/', token: 'secret') }
      let(:single_broker_response) do
        {
          'total_results' => 1,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'metadata' => {
                'guid' => broker.guid,
                'url' => "/v2/service_brokers/#{broker.guid}",
                'created_at' => broker.created_at.iso8601,
                'updated_at' => nil,
              },
              'entity' => {
                'name' => broker.name,
                'broker_url' => broker.broker_url,
              }
            }
          ],
        }
      end

      it "enumerates the things" do
        get '/v2/service_brokers', {}, headers
        expect(decoded_response).to eq(single_broker_response)
      end

      context "with a second service broker" do
        let!(:broker2) { Models::ServiceBroker.make(name: 'FreeWidgets2', broker_url: 'http://example.com/2', token: 'secret2') }

        it "filters the things" do
          get "/v2/service_brokers?q=name%3A#{broker.name}", {}, headers
          expect(decoded_response).to eq(single_broker_response)
        end
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          get '/v2/service_brokers', {}, non_admin_headers
          expect(last_response).to be_forbidden
        end

        it 'returns 401 for logged-out users' do
          get '/v2/service_brokers'
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe "DELETE /v2/service_brokers/:guid" do
      let!(:broker) { Models::ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/', token: 'secret') }

      it "deletes the service broker" do
        delete "/v2/service_brokers/#{broker.guid}", {}, headers

        expect(last_response.status).to eq(204)

        get '/v2/service_brokers', {}, headers
        expect(decoded_response).to include('total_results' => 0)
      end

      it "returns 404 when deleting a service broker that does not exist" do
        delete "/v2/service_brokers/1234", {}, headers
        expect(last_response.status).to eq(404)
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          delete "/v2/service_brokers/#{broker.guid}", {}, non_admin_headers
          expect(last_response).to be_forbidden

          # make sure it still exists
          get '/v2/service_brokers', {}, headers
          expect(decoded_response).to include('total_results' => 1)
        end

        it 'returns 401 for logged-out users' do
          delete "/v2/service_brokers/#{broker.guid}"
          expect(last_response.status).to eq(401)

          # make sure it still exists
          get '/v2/service_brokers', {}, headers
          expect(decoded_response).to include('total_results' => 1)
        end
      end
    end

    describe 'PUT /v2/service_brokers/:guid' do
      let(:old_broker_url) { 'http://old-cf-service-broker.example.com' }

      def old_broker_api_url(token = nil)
        token ||= self.token
        "http://cc:#{token}@old-cf-service-broker.example.com/v3"
      end

      let(:new_broker_url) { 'http://cf-service-broker.example.com' }

      def new_broker_api_url(token = nil)
        token ||= self.token
        "http://cc:#{token}@cf-service-broker.example.com/v3"
      end

      let(:token) { 'secret' }

      let!(:broker) { Models::ServiceBroker.make(name: 'FreeWidgets', broker_url: old_broker_url, token: token) }

      before do
        stub_request(:get, old_broker_api_url).to_return(status: 200, body: '["OK"]')
        stub_request(:get, new_broker_api_url).to_return(status: 200, body: '["OK"]')
      end

      it "updates the name and url of an existing service broker" do
        payload = {
          "name" => "expensiveWidgets",
          "broker_url" => new_broker_url,
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::OK)
        expect(decoded_response["entity"]).to eq(
          "name" => "expensiveWidgets",
          "broker_url" => new_broker_url,
        )

        get '/v2/service_brokers', {}, headers
        entity = decoded_response.fetch('resources').fetch(0).fetch('entity')
        expect(entity).to eq(
          "name" => "expensiveWidgets",
          "broker_url" => new_broker_url,
        )
      end

      it "updates the token of an existing service broker" do
        stub_request(:get, old_broker_api_url('seeeecret')).to_return(status: 200, body: '["OK"]')
        payload = {
          "token" => "seeeecret",
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::OK)
        broker.reload
        expect(broker.token).to eq("seeeecret")
      end

      it 'does not allow blank name' do
        payload = {
          "name" => "",
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::BAD_REQUEST)
        expect(decoded_response.fetch('code')).to eq(270001)
        expect(decoded_response.fetch('description')).to match(/name presence/)
      end

      it 'does not allow blank url' do
        payload = {
          "broker_url" => "",
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::BAD_REQUEST)
        expect(decoded_response.fetch('code')).to eq(270001)
        expect(decoded_response.fetch('description')).to match(/broker_url presence/)
      end

      it 'does not allow blank token' do
        payload = {
          "token" => "",
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::BAD_REQUEST)
        expect(decoded_response.fetch('code')).to eq(270001)
        expect(decoded_response.fetch('description')).to match(/token presence/)
      end

      it 'does not set fields that are unmodifiable' do
        expect {
          put "/v2/service_brokers/#{broker.guid}", {guid: 'mycustomguid'}, headers
        }.not_to change { broker.reload.guid }
      end

      context 'when specifying an unknown broker' do
        it 'returns 404' do
          payload = {
            "name" => "whatever",
          }.to_json
          put "/v2/service_brokers/nonexistent", payload, headers

          expect(last_response.status).to eq(HTTP::NOT_FOUND)
        end
      end

      context 'when the broker API check fails' do
        let(:body) do
          {
            broker_url: new_broker_url
          }.to_json
        end

        before do
          stub_request(:get, new_broker_api_url).to_raise(SocketError)
        end

        it 'returns an error' do
          error = Errors::ServiceBrokerApiUnreachable.new(new_broker_url)

          put "/v2/service_brokers/#{broker.guid}", body, headers

          last_response.status.should == error.response_code
          decoded_response.fetch('code').should == error.error_code
          decoded_response.fetch('description').should == error.message
        end

        it 'does not update the broker record' do
          expect {
            put "/v2/service_brokers/#{broker.guid}", body, headers
          }.to_not change(Models::ServiceBroker, :count)

          broker.reload
          expect(broker.broker_url).to_not eq(new_broker_url)
        end
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          put "/v2/service_brokers/#{broker.guid}", {}, non_admin_headers
          expect(last_response).to be_forbidden
        end

        it 'returns 401 for logged-out users' do
          put "/v2/service_brokers/#{broker.guid}", {}
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
