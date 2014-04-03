require 'spec_helper'

module VCAP::CloudController
  describe ServiceBrokersController, :services, type: :controller do
    let(:headers) { json_headers(admin_headers) }

    let(:non_admin_headers) do
      user = VCAP::CloudController::User.make(admin: false)
      json_headers(headers_for(user))
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
        reg.stub(:create).and_return(reg)
        reg
      end
      let(:presenter) { double(ServiceBrokerPresenter, {
        to_json: "{\"metadata\":{\"guid\":\"#{broker.guid}\"}}"
      }) }

      before do
        ServiceBroker.stub(:new).and_return(broker)
        VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.stub(:new).with(broker).and_return(registration)
        ServiceBrokerPresenter.stub(:new).with(broker).and_return(presenter)
      end

      it 'returns a 201 status' do
        post '/v2/service_brokers', body, headers

        expect(last_response.status).to eq(201)
      end

      it 'creates a service broker registration' do
        post '/v2/service_brokers', body, headers

        expect(registration).to have_received(:create)
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
        expect(ServiceBroker).to_not have_received(:new).with(hash_including('guid' => 'mycustomguid'))
      end

      context 'when there is an error in Broker Registration' do
        before { registration.stub(:create).and_return(nil) }

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
          let(:error_message) { 'A bunch of stuff was wrong' }
          before do
            errors.stub(:full_messages).and_return([error_message])
            registration.stub(:create).and_raise(Sequel::ValidationFailed.new(errors))
          end

          it 'returns an error' do
            post '/v2/service_brokers', body, headers

            last_response.status.should == 502
            decoded_response.fetch('code').should == 270012
            decoded_response.fetch('description').should == 'Service broker catalog is invalid: A bunch of stuff was wrong'
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
      let!(:broker) { ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/') }
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
                'updated_at' => nil
              },
              'entity' => {
                'name' => broker.name,
                'broker_url' => broker.broker_url,
                'auth_username' => broker.auth_username,
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
        let!(:broker2) { ServiceBroker.make(name: 'FreeWidgets2', broker_url: 'http://example.com/2') }

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
          expect(decoded_response).to include({
            'error_code' => 'CF-InvalidAuthToken'
          })
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

      context "when a service instance exists", non_transactional: true do
        it "returns a 400 and an appropriate error message" do
          service = Service.make(:service_broker => broker)
          service_plan = ServicePlan.make(:service => service)
          ManagedServiceInstance.make(:service_plan => service_plan)

          delete "/v2/service_brokers/#{broker.guid}", {}, headers

          expect(last_response.status).to eq(400)
          decoded_response.fetch('code').should == 270010
          decoded_response.fetch('description').should =~ /Can not remove brokers that have associated service instances/

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
        reg.stub(:update).and_return(reg)
        reg
      end
      let(:presenter) { double(ServiceBrokerPresenter, {
        to_json: "{\"metadata\":{\"guid\":\"#{broker.guid}\"}}"
      }) }

      before do
        ServiceBroker.stub(:find)
        ServiceBroker.stub(:find).with(guid: broker.guid).and_return(broker)
        VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.stub(:new).with(broker).and_return(registration)
        ServiceBrokerPresenter.stub(:new).with(broker).and_return(presenter)
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

      it 'does not set fields that are unmodifiable' do
        body_hash['guid'] = 'hacked'
        put "/v2/service_brokers/#{broker.guid}", body, headers

        expect(broker).to_not have_received(:set).with(hash_including('guid' => 'hacked'))
      end

      context 'when specifying an unknown broker' do
        it 'returns 404' do
          put '/v2/service_brokers/nonexistent', body, headers

          expect(last_response.status).to eq(HTTP::NOT_FOUND)
        end
      end

      context 'when there is an error in Broker Registration' do
        before { registration.stub(:update).and_return(nil) }

        context 'when the broker url is not a valid http/https url' do
          before { errors.stub(:on).with(:broker_url).and_return([:url]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270011
            decoded_response.fetch('description').should =~ /is not a valid URL/
          end
        end

        context 'when the broker url is taken' do
          before { errors.stub(:on).with(:broker_url).and_return([:unique]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270003
            decoded_response.fetch('description').should =~ /The service broker url is taken/
          end
        end

        context 'when the broker name is taken' do
          before { errors.stub(:on).with(:name).and_return([:unique]) }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270002
            decoded_response.fetch('description').should =~ /The service broker name is taken/
          end
        end

        context 'when there are other errors on the registration' do
          before { errors.stub(:full_messages).and_return('A bunch of stuff was wrong') }

          it 'returns an error' do
            put "/v2/service_brokers/#{broker.guid}", body, headers

            last_response.status.should == 400
            decoded_response.fetch('code').should == 270001
            decoded_response.fetch('description').should == 'Service broker is invalid: A bunch of stuff was wrong'
          end
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
