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
      let(:broker_url) { Sham.url }
      let(:token) { 'you should never see me in the response' }

      let(:body) do
        {
          name: name,
          broker_url: broker_url,
          token: token
        }.to_json
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
                'created_at' => broker.created_at.to_s,
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
      let!(:broker) { Models::ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/', token: 'secret') }

      it "updates the name and url of an existing service broker" do
        payload = {
          "name" => "expensiveWidgets",
          "broker_url" => "http://blah.example.com/",
        }.to_json
        put "/v2/service_brokers/#{broker.guid}", payload, headers

        expect(last_response.status).to eq(HTTP::OK)
        expect(decoded_response["entity"]).to eq(
          "name" => "expensiveWidgets",
          "broker_url" => "http://blah.example.com/",
        )

        get '/v2/service_brokers', {}, headers
        entity = decoded_response.fetch('resources').fetch(0).fetch('entity')
        expect(entity).to eq(
          "name" => "expensiveWidgets",
          "broker_url" => "http://blah.example.com/",
        )
      end

      it "updates the token of an existing service broker" do
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

      context 'when specifying an unknown broker' do
        it 'returns 404' do
          payload = {
            "name" => "whatever",
          }.to_json
          put "/v2/service_brokers/nonexistent", payload, headers

          expect(last_response.status).to eq(HTTP::NOT_FOUND)
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
