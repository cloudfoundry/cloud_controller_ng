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
      let(:token) { 'abc123' }

      let(:body_hash) do
        {
          name: name,
          broker_url: broker_url,
          token: token
        }
      end

      def body
        body_hash.to_json
      end

      let(:errors) { double(Sequel::Model::Errors, on: nil) }
      let(:broker) do
        double(Models::ServiceBroker, {
          guid: '123',
          name: 'My Custom Service',
          broker_url: 'http://broker.example.com',
          token: 'abc123'
        })
      end
      let(:registration) do
        reg = double(Models::ServiceBrokerRegistration, {
          broker: broker,
          errors: errors
        })
        reg.stub(:save).and_return(reg)
        reg
      end
      let(:presenter) { double(ServiceBrokerPresenter, {
        to_json: "{\"metadata\":{\"guid\":\"#{broker.guid}\"}}"
      }) }

      before do
        Models::ServiceBrokerRegistration.stub(:new).and_return(registration)
        ServiceBrokerPresenter.stub(:new).with(broker).and_return(presenter)
      end

      it 'returns a 201 status' do
        post '/v2/service_brokers', body, headers

        expect(last_response.status).to eq(201)
      end

      it 'creates a service broker registration' do
        post '/v2/service_brokers', body, headers

        expect(registration).to have_received(:save)
      end

      it 'returns the serialized broker' do
        post '/v2/service_brokers', body, headers

        expect(last_response.body).to eq(presenter.to_json)
      end

      it 'includes a location header for the resource' do
        post '/v2/service_brokers', body, headers

        headers = last_response.original_headers
        headers.fetch('Location').should == '/v2/service_brokers/123'
      end

      it 'does not set fields that are unmodifiable' do
        body_hash[:guid] = 'mycustomguid'
        post '/v2/service_brokers', body, headers
        expect(Models::ServiceBrokerRegistration).to_not have_received(:new).with(hash_including('guid' => 'mycustomguid'))
      end

      context 'when there is an error in Broker Registration' do
        before { registration.stub(:save).and_return(nil) }

        context 'when there is an error in API authentication' do
          before { errors.stub(:on).with(:broker_api).and_return([:authentication_failed]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270007
            decoded_response.fetch('description').should =~ /The Service Broker API authentication failed/
          end
        end

        context 'when the broker API is unreachable' do
          before { errors.stub(:on).with(:broker_api).and_return([:unreachable]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270004
            decoded_response.fetch('description').should =~ /The Service Broker API could not be reached/
          end
        end

        context 'when the broker API times out' do
          before { errors.stub(:on).with(:broker_api).and_return([:timeout]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270005
            decoded_response.fetch('description').should =~ /The Service Broker API timed out/
          end
        end

        context "when the broker's catalog is malformed" do
          before { errors.stub(:on).with(:catalog).and_return([:malformed]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270006
            decoded_response.fetch('description').should =~ /The Service Broker's catalog endpoint did not return valid json/
          end
        end

        context 'when the broker url is taken' do
          before { errors.stub(:on).with(:broker_url).and_return([:unique]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270003
            decoded_response.fetch('description').should =~ /The service broker url is taken/
          end
        end

        context 'when the broker name is taken' do
          before { errors.stub(:on).with(:name).and_return([:unique]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270002
            decoded_response.fetch('description').should =~ /The service broker name is taken/
          end
        end

        context 'when there are other errors on the registration' do
          before { errors.stub(:full_messages).and_return('A bunch of stuff was wrong') }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270001
            decoded_response.fetch('description').should == 'Service Broker is invalid: A bunch of stuff was wrong'
          end
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

    describe 'GET /v2/service_brokers' do
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

    describe 'DELETE /v2/service_brokers/:guid' do
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
      let(:existing_broker_url) { 'http://old-cf-service-broker.example.com' }

      def existing_broker_catalog_url(token = nil)
        token ||= self.token
        "http://cc:#{token}@old-cf-service-broker.example.com/v2/catalog"
      end

      let(:new_broker_url) { 'http://cf-service-broker.example.com' }

      def new_broker_catalog_url(token = nil)
        token ||= self.token
        "http://cc:#{token}@cf-service-broker.example.com/v2/catalog"
      end

      let(:token) { 'secret' }

      let!(:broker) { Models::ServiceBroker.make(name: 'FreeWidgets', broker_url: existing_broker_url, token: token) }

      before do
        stub_request(:get, existing_broker_catalog_url).to_return(status: 200, body: '{}')
        stub_request(:get, new_broker_catalog_url).to_return(status: 200, body: '{}')
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
        stub_request(:get, existing_broker_catalog_url('seeeecret')).to_return(status: 200, body: '{}')
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
          stub_request(:get, new_broker_catalog_url).to_raise(SocketError)
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
