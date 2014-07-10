require 'spec_helper'

module VCAP::CloudController
  describe ServiceBrokersController, :services do
    let(:headers) { json_headers(admin_headers) }

    let(:non_admin_headers) do
      user = VCAP::CloudController::User.make(admin: false)
      json_headers(headers_for(user))
    end

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name: {type: "string", required: true},
          broker_url: {type: "string", required: true},
          auth_username: {type: "string", required: true},
          auth_password: {type: "string", required: true}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: {type: "string"},
          broker_url: {type: "string"},
          auth_username: {type: "string"},
          auth_password: {type: "string"}
        })
      end
    end

    describe 'POST /v2/service_brokers' do
      let(:name) { Sham.name }
      let(:broker_url) { 'http://cf-service-broker.example.com' }
      let(:auth_username) { 'me' }
      let(:auth_password) { 'abc123' }

      let(:body_hash) do
        {
          name: name,
          broker_url: broker_url,
          auth_username: auth_username,
          auth_password: auth_password,
        }
      end

      def body
        body_hash.to_json
      end

      let(:errors) { double(Sequel::Model::Errors, on: nil) }
      let(:broker) do
        double(ServiceBroker, {
          guid: '123',
          name: 'My Custom Service',
          broker_url: 'http://broker.example.com',
          auth_username: 'me',
          auth_password: 'abc123',
        })
      end
      let(:registration) do
        reg = double(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration, {
          broker: broker,
          errors: errors,
        })
        allow(reg).to receive(:create).and_return(reg)
        allow(reg).to receive(:warnings).and_return([])
        reg
      end
      let(:presenter) { double(ServiceBrokerPresenter, {
        to_json: "{\"metadata\":{\"guid\":\"#{broker.guid}\"}}"
      }) }

      before do
        allow(ServiceBroker).to receive(:new).and_return(broker)
        allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new).with(broker).and_return(registration)
        allow(ServiceBrokerPresenter).to receive(:new).with(broker).and_return(presenter)
      end

      it 'creates a service broker registration' do
        post '/v2/service_brokers', body, headers

        expect(last_response.status).to eq(201)
        expect(registration).to have_received(:create)
      end

      it 'returns the serialized broker' do
        post '/v2/service_brokers', body, headers

        expect(last_response.body).to eq(presenter.to_json)
      end

      it 'includes a location header for the resource' do
        post '/v2/service_brokers', body, headers

        headers = last_response.original_headers
        expect(headers.fetch('Location')).to eq('/v2/service_brokers/123')
      end

      context 'when there is an error in Broker Registration' do
        before { allow(registration).to receive(:create).and_return(nil) }

        context 'when the broker url is taken' do
          before { allow(errors).to receive(:on).with(:broker_url).and_return([:unique]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270003)
          end
        end

        context 'when the broker name is taken' do
          before { allow(errors).to receive(:on).with(:name).and_return([:unique]) }

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270002)
          end
        end

        context 'when there are other errors on the registration' do
          let(:error_message) { 'A bunch of stuff was wrong' }
          before do
            allow(errors).to receive(:full_messages).and_return([error_message])
            allow(registration).to receive(:create).and_raise(Sequel::ValidationFailed.new(errors))
          end

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            expect(last_response.status).to eq(502)
            expect(decoded_response.fetch('code')).to eq(270012)
            expect(decoded_response.fetch('description')).to eq('Service broker catalog is invalid: A bunch of stuff was wrong')
          end
        end
      end

      context 'when the broker registration has warnings' do
        before do
          allow(registration).to receive(:warnings).and_return(['warning1','warning2'])
        end

        it 'adds the warnings' do
          post('/v2/service_brokers', body, headers)

          warnings = last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
          expect(warnings.length).to eq(2)
          expect(warnings[0]).to eq('warning1')
          expect(warnings[1]).to eq('warning2')
        end
      end
    end

    describe 'DELETE /v2/service_brokers/:guid' do
      let!(:broker) { ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/', auth_password: 'secret') }

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

      context "when a service instance exists", isolation: :truncation do
        it "returns a 400 and an appropriate error message" do
          service = Service.make(:service_broker => broker)
          service_plan = ServicePlan.make(:service => service)
          ManagedServiceInstance.make(:service_plan => service_plan)

          delete "/v2/service_brokers/#{broker.guid}", {}, headers

          expect(last_response.status).to eq(400)
          expect(decoded_response.fetch('code')).to eq(270010)
          expect(decoded_response.fetch('description')).to match(/Can not remove brokers that have associated service instances/)

          get '/v2/service_brokers', {}, headers
          expect(decoded_response).to include('total_results' => 1)
        end
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          delete "/v2/service_brokers/#{broker.guid}", {}, non_admin_headers
          expect(last_response).to be_forbidden

          # make sure it still exists
          get '/v2/service_brokers', {}, headers
          expect(decoded_response).to include('total_results' => 1)
        end
      end
    end

    describe 'PUT /v2/service_brokers/:guid' do
      let(:body_hash) do
        {
          name: 'My Updated Service',
          broker_url: 'http://new-broker.example.com',
          auth_username: 'new-username',
          auth_password: 'new-password',
        }
      end

      def body
        body_hash.to_json
      end

      let(:errors) { double(Sequel::Model::Errors, on: nil) }
      let(:broker) do
        double(ServiceBroker, {
          guid: '123',
          name: 'My Custom Service',
          broker_url: 'http://broker.example.com',
          auth_username: 'me',
          auth_password: 'abc123',
          set: nil
        })
      end
      let(:registration) do
        reg = double(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration, {
          broker: broker,
          errors: errors
        })
        allow(reg).to receive(:update).and_return(reg)
        allow(reg).to receive(:warnings).and_return([])
        reg
      end
      let(:presenter) { double(ServiceBrokerPresenter, {
        to_json: "{\"metadata\":{\"guid\":\"#{broker.guid}\"}}"
      }) }

      before do
        allow(ServiceBroker).to receive(:find)
        allow(ServiceBroker).to receive(:find).with(guid: broker.guid).and_return(broker)
        allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new).with(broker).and_return(registration)
        allow(ServiceBrokerPresenter).to receive(:new).with(broker).and_return(presenter)
      end

      it 'updates the broker' do
        put "/v2/service_brokers/#{broker.guid}", body, headers

        expect(broker).to have_received(:set).with(body_hash)
        expect(registration).to have_received(:update)
      end


      it 'returns the serialized broker' do
        put "/v2/service_brokers/#{broker.guid}", body, headers

        expect(last_response.body).to eq(presenter.to_json)
      end

      context 'when specifying an unknown broker' do
        it 'returns 404' do
          put '/v2/service_brokers/nonexistent', body, headers

          expect(last_response.status).to eq(HTTP::NOT_FOUND)
        end
      end

      context 'when there is an error in Broker Registration' do
        before { allow(registration).to receive(:update).and_return(nil) }

        context 'when the broker url is not a valid http/https url' do
          before { allow(errors).to receive(:on).with(:broker_url).and_return([:url]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270011)
            expect(decoded_response.fetch('description')).to match(/is not a valid URL/)
          end
        end

        context 'when the broker url is taken' do
          before { allow(errors).to receive(:on).with(:broker_url).and_return([:unique]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270003)
            expect(decoded_response.fetch('description')).to match(/The service broker url is taken/)
          end
        end

        context 'when the broker name is taken' do
          before { allow(errors).to receive(:on).with(:name).and_return([:unique]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270002)
            expect(decoded_response.fetch('description')).to match(/The service broker name is taken/)
          end
        end

        context 'when there are other errors on the registration' do
          before { allow(errors).to receive(:full_messages).and_return('A bunch of stuff was wrong') }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            expect(last_response.status).to eq(400)
            expect(decoded_response.fetch('code')).to eq(270001)
            expect(decoded_response.fetch('description')).to eq('Service broker is invalid: A bunch of stuff was wrong')
          end
        end
      end

      context 'when the broker registration has warnings' do
        before do
          allow(registration).to receive(:warnings).and_return(['warning1','warning2'])
        end

        it 'adds the warnings' do
          put("/v2/service_brokers/#{broker.guid}", body, headers)

          warnings = last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
          expect(warnings.length).to eq(2)
          expect(warnings[0]).to eq('warning1')
          expect(warnings[1]).to eq('warning2')
        end
      end

      describe 'authentication' do
        it 'returns a forbidden status for non-admin users' do
          put "/v2/service_brokers/#{broker.guid}", {}, non_admin_headers
          expect(last_response).to be_forbidden
        end
      end
    end
  end
end
