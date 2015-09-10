require 'spec_helper'

module VCAP::CloudController
  describe ServiceBrokersController, :services do
    let(:headers) { headers_for(admin_user) }
    let(:broker) { ServiceBroker.make }
    let(:catalog_json) do
      {
        'services' => [{
            'name' => 'fake-service',
            'id' => 'f479b64b-7c25-42e6-8d8f-e6d22c456c9b',
            'description' => 'fake service',
            'tags' => ['no-sql', 'relational'],
            'max_db_per_node' => 5,
            'bindable' => true,
            'metadata' => {
              'provider' => { 'name' => 'The name' },
              'listing' => {
                'imageUrl' => 'http://catgifpage.com/cat.gif',
                'blurb' => 'fake broker that is fake',
                'longDescription' => 'A long time ago, in a galaxy far far away...'
              },
              'displayName' => 'The Fake Broker'
            },
            'dashboard_client' => nil,
            'plan_updateable' => true,
            'plans' => [{
                'name' => 'fake-plan',
                'id' => 'f52eabf8-e38d-422f-8ef9-9dc83b75cc05',
                'description' => 'Shared fake Server, 5tb persistent disk, 40 max concurrent connections',
                'max_storage_tb' => 5,
                'metadata' => {
                  'cost' => 0.0,
                  'bullets' => [
                    { 'content' => 'Shared fake server' },
                    { 'content' => '5 TB storage' },
                    { 'content' => '40 concurrent connections' }
                  ],
                },
              }],
          }],
      }
    end

    let(:broker_catalog_url) do
      attributes = {
        url: body_hash[:url] || body_hash[:broker_url],
        auth_username: body_hash[:auth_username],
        auth_password: body_hash[:auth_password],
      }
      build_broker_url(attributes, '/v2/catalog')
    end

    def stub_catalog(broker_url: nil)
      url = broker_url || broker_catalog_url
      stub_request(:get, url).
          to_return(status: 200, body: catalog_json.to_json)
    end

    let(:non_admin_headers) do
      user = VCAP::CloudController::User.make(admin: false)
      json_headers(headers_for(user))
    end

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          broker_url: { type: 'string', required: true },
          auth_username: { type: 'string', required: true },
          auth_password: { type: 'string', required: true },
          space_guid: { type: 'string', required: false }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          broker_url: { type: 'string' },
          auth_username: { type: 'string' },
          auth_password: { type: 'string' }
        })
      end
    end

    describe 'GET /v2/service_brokers' do
      let(:space_a) { Space.make }
      let(:space_b) { Space.make }
      let(:user) { User.make }
      let!(:public_broker) { ServiceBroker.make }
      let!(:space_a_broker) { ServiceBroker.make space: space_a }
      let!(:space_b_broker) { ServiceBroker.make space: space_b }

      it 'can filter brokers by name' do
        get "/v2/service_brokers?q=name:#{public_broker.name}", {}, admin_headers

        expect(last_response).to have_status_code(200)
        expect(decoded_response['total_results']).to eq(1)
        expect(decoded_response['resources'].first['metadata']['guid']).to eq(public_broker.guid)
        expect(decoded_response['resources'].first['entity']['name']).to eq(public_broker.name)
      end

      it 'can filter brokers by space_guid' do
        get "/v2/service_brokers?q=space_guid:#{space_a_broker.space_guid}", {}, admin_headers

        expect(last_response).to have_status_code(200)
        expect(decoded_response['total_results']).to eq(1)
        expect(decoded_response['resources'].first['metadata']['guid']).to eq(space_a_broker.guid)
        expect(decoded_response['resources'].first['entity']['space_guid']).to eq(space_a_broker.space_guid)
      end

      context 'as an Admin' do
        it 'sees all brokers' do
          get '/v2/service_brokers', {}, admin_headers

          expect(last_response).to have_status_code(200)
          expect(decoded_response['total_results']).to eq(3)
        end
      end

      context 'as a SpaceDeveloper for space_a' do
        before do
          space_a.organization.add_user user
          space_a.add_developer user
        end

        it 'sees only private brokers in space_a' do
          get '/v2/service_brokers', {}, headers_for(user)

          expect(last_response).to have_status_code(200)
          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'].first['metadata']['guid']).to eq(space_a_broker.guid)
        end

        it 'sees only private broker in space_a when filtering' do
          get "/v2/service_brokers?q=name:#{public_broker.name}", {}, headers_for(user)
          expect(last_response).to have_status_code(200)
          expect(decoded_response['total_results']).to eq(0)

          get "/v2/service_brokers?q=name:#{space_a_broker.name}", {}, headers_for(user)
          expect(last_response).to have_status_code(200)
          expect(decoded_response['total_results']).to eq(1)
        end
      end

      context 'as an unaffiliated user' do
        it 'sees no brokers' do
          get '/v2/service_brokers', {}, headers_for(user)

          expect(last_response).to have_status_code(200)
          expect(decoded_response['total_results']).to eq(0)
          expect(decoded_response['resources']).to eq([])
        end
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

      let(:body) { body_hash.to_json }
      let(:errors) { instance_double(Sequel::Model::Errors, on: nil) }

      it 'creates a broker create event' do
        email = 'email@example.com'
        stub_catalog
        post '/v2/service_brokers', body, headers_for(admin_user, email: email)
        broker = ServiceBroker.last

        event = Event.first(type: 'audit.service_broker.create')
        expect(event.actor_type).to eq('user')
        expect(event.timestamp).to be
        expect(event.actor).to eq(admin_user.guid)
        expect(event.actor_name).to eq(email)
        expect(event.actee).to eq(broker.guid)
        expect(event.actee_type).to eq('service_broker')
        expect(event.actee_name).to eq(body_hash[:name])
        expect(event.space_guid).to be_empty
        expect(event.organization_guid).to be_empty
        expect(event.metadata).to include({
          'request' => {
            'name' => body_hash[:name],
            'broker_url' => body_hash[:broker_url],
            'auth_username' => body_hash[:auth_username],
            'auth_password' => '[REDACTED]',
          }
        })
      end

      it 'creates a service broker registration' do
        stub_catalog
        post '/v2/service_brokers', body, headers

        expect(last_response).to have_status_code(201)
        expect(a_request(:get, broker_catalog_url)).to have_been_made
      end

      it 'returns the serialized broker' do
        stub_catalog
        post '/v2/service_brokers', body, headers

        service_broker = ServiceBroker.last
        expect(MultiJson.load(last_response.body)).to eq(
          'metadata' => {
            'guid' => service_broker.guid,
            'created_at' => service_broker.created_at.iso8601,
            'updated_at' => nil,
            'url' => "/v2/service_brokers/#{service_broker.guid}",
          },
          'entity' =>  {
            'name' => name,
            'broker_url' => broker_url,
            'auth_username' => auth_username,
            'space_guid' => nil,
          },
        )
      end

      it 'includes a location header for the resource' do
        stub_catalog
        post '/v2/service_brokers', body, headers

        headers = last_response.original_headers
        broker = ServiceBroker.last
        expect(headers.fetch('Location')).to eq("/v2/service_brokers/#{broker.guid}")
      end

      describe 'adding a broker to a space only' do
        let(:space) { Space.make }
        let(:body) { body_hash.merge({ space_guid: space.guid }).to_json }

        it 'creates a broker with an associated space' do
          stub_catalog

          post '/v2/service_brokers', body, headers

          expect(last_response).to have_status_code(201)
          parsed_body = JSON.load(last_response.body)
          expect(parsed_body['entity']).to include({ 'space_guid' => space.guid })
          expect(a_request(:get, broker_catalog_url)).to have_been_made

          broker = ServiceBroker.last
          expect(broker.space).to eq(space)
        end

        it 'returns a 403 if a user is not a SpaceDeveloper for the space' do
          user = User.make

          post '/v2/service_brokers', body, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        it 'returns a 400 if a another broker (private or public) exists with that name' do
          stub_catalog broker_url: 'http://me:abc123@cf-service-broker.example-2.com/v2/catalog'

          public_body = {
            name:          name,
            broker_url:    'http://cf-service-broker.example-2.com',
            auth_username: auth_username,
            auth_password: auth_password,
          }.to_json

          post '/v2/service_brokers', public_body, headers
          expect(last_response).to have_status_code(201)

          post '/v2/service_brokers', body, headers
          expect(last_response).to have_status_code(400)
        end

        it 'returns a 400 if a another broker (private or public) exists with that url' do
          stub_catalog

          public_body = {
            name:          'other-name',
            broker_url:    broker_url,
            auth_username: auth_username,
            auth_password: auth_password,
          }.to_json

          post '/v2/service_brokers', public_body, headers
          expect(last_response).to have_status_code(201)

          post '/v2/service_brokers', body, headers
          expect(last_response).to have_status_code(400)
        end

        it 'returns a 404 if the space does not exist' do
          space.destroy
          stub_catalog

          post '/v2/service_brokers', body, headers

          expect(last_response).to have_status_code(404)
          parsed_body = JSON.load(last_response.body)
          expect(parsed_body['description']).to include('Space not found')
        end
      end

      context 'when the user is a SpaceDeveloper' do
        let(:user) { User.make }
        let(:space) { Space.make }

        before do
          space.organization.add_user user
          space.add_developer user
        end

        it 'returns a 403 if the SpaceDeveloper does not include a space_guid' do
          post '/v2/service_brokers', body, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end

      context 'when the fields for creating the broker is invalid' do
        context 'when the broker url is malformed' do
          let(:broker_url) { 'http://url_with_underscore.broker.com' }

          it 'returns a 400 error' do
            post '/v2/service_brokers', body, headers
            expect(last_response).to have_status_code(400)
            expect(decoded_response.fetch('code')).to eq(270011)
          end
        end

        context 'when the broker url is taken' do
          before do
            ServiceBroker.make(broker_url: body_hash[:broker_url])
          end

          it 'returns an error' do
            stub_catalog
            post '/v2/service_brokers', body, headers

            expect(last_response).to have_status_code(400)
            expect(decoded_response.fetch('code')).to eq(270003)
          end
        end

        context 'when the broker name is taken' do
          before do
            ServiceBroker.make(name: body_hash[:name])
          end

          it 'returns an error' do
            stub_catalog
            post '/v2/service_brokers', body, headers

            expect(last_response).to have_status_code(400)
            expect(decoded_response.fetch('code')).to eq(270002)
          end
        end

        context 'when catalog response is invalid' do
          let(:catalog_json) do
            {}
          end

          it 'returns an error' do
            stub_catalog
            post '/v2/service_brokers', body, headers

            expect(last_response).to have_status_code(502)
            expect(decoded_response.fetch('code')).to eq(270012)
            expect(decoded_response.fetch('description')).to include('Service broker catalog is invalid:')
            expect(decoded_response.fetch('description')).to include('Service broker must provide at least one service')
          end
        end
      end

      context 'when the CC is not configured to use the UAA correctly and the service broker requests dashboard access' do
        before do
          VCAP::CloudController::Config.config[:uaa_client_name] = nil
          VCAP::CloudController::Config.config[:uaa_client_secret] = nil

          catalog_json['services'][0]['dashboard_client'] = {
            id: 'p-mysql-client',
            secret: 'p-mysql-secret',
            redirect_uri: 'http://p-mysql.example.com',
          }
        end

        it 'emits warnings as headers to the CC client' do
          stub_catalog
          post('/v2/service_brokers', body, headers)

          warnings = last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
          expect(warnings.length).to eq(1)
          expect(warnings[0]).to eq(VCAP::Services::SSO::DashboardClientManager::REQUESTED_FEATURE_DISABLED_WARNING)
        end
      end
    end

    describe 'DELETE /v2/service_brokers/:guid' do
      let!(:broker) { ServiceBroker.make(name: 'FreeWidgets', broker_url: 'http://example.com/', auth_password: 'secret') }

      it 'deletes the service broker' do
        delete "/v2/service_brokers/#{broker.guid}", {}, headers

        expect(last_response).to have_status_code(204)

        get '/v2/service_brokers', {}, headers
        expect(decoded_response).to include('total_results' => 0)
      end

      it 'creates a broker delete event' do
        email = 'some-email-address@example.com'
        delete "/v2/service_brokers/#{broker.guid}", {}, headers_for(admin_user, email: email)

        event = Event.first(type: 'audit.service_broker.delete')
        expect(event.actor_type).to eq('user')
        expect(event.timestamp).to be
        expect(event.actor).to eq(admin_user.guid)
        expect(event.actor_name).to eq(email)
        expect(event.actee).to eq(broker.guid)
        expect(event.actee_type).to eq('service_broker')
        expect(event.actee_name).to eq(broker.name)
        expect(event.space_guid).to be_empty
        expect(event.organization_guid).to be_empty
        expect(event.metadata).to have_key('request')
        expect(event.metadata['request']).to be_empty
      end

      it 'returns 404 when deleting a service broker that does not exist' do
        delete '/v2/service_brokers/1234', {}, headers
        expect(last_response.status).to eq(404)
      end

      context 'when a service instance exists', isolation: :truncation do
        it 'returns a 400 and an appropriate error message' do
          service = Service.make(service_broker: broker)
          service_plan = ServicePlan.make(service: service)
          ManagedServiceInstance.make(service_plan: service_plan)

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
          auth_username: 'new-username',
          auth_password: 'new-password',
        }
      end

      let(:body) { body_hash.to_json }
      let(:errors) { instance_double(Sequel::Model::Errors, on: nil) }
      let(:broker) do
        ServiceBroker.make(
          guid: '123',
          name: 'My Custom Service',
          broker_url: 'http://broker.example.com',
          auth_username: 'me',
          auth_password: 'abc123',
        )
      end

      before do
        attrs = {
          url: 'http://broker.example.com',
          auth_username: 'new-username',
          auth_password: 'new-password',
        }
        stub_request(:get, build_broker_url(attrs, '/v2/catalog')).
          to_return(status: 200, body: catalog_json.to_json)
      end

      context 'when changing credentials' do
        it 'creates a broker update event' do
          old_broker_name = broker.name
          body_hash.delete(:broker_url)
          email = 'email@example.com'

          put "/v2/service_brokers/#{broker.guid}", body, headers_for(admin_user, email: email)

          event = Event.first(type: 'audit.service_broker.update')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(admin_user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(broker.guid)
          expect(event.actee_type).to eq('service_broker')
          expect(event.actee_name).to eq(old_broker_name)
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to be_empty
          expect(event.metadata['request']['name']).to eq body_hash[:name]
          expect(event.metadata['request']['auth_username']).to eq body_hash[:auth_username]
          expect(event.metadata['request']['auth_password']).to eq '[REDACTED]'
          expect(event.metadata['request']).not_to have_key 'broker_url'
        end

        it 'updates the broker' do
          put "/v2/service_brokers/#{broker.guid}", body, headers

          broker.reload
          expect(broker.name).to eq(body_hash[:name])
          expect(broker.auth_username).to eq(body_hash[:auth_username])
          expect(broker.auth_password).to eq(body_hash[:auth_password])
        end

        it 'returns the serialized broker' do
          put "/v2/service_brokers/#{broker.guid}", body, headers

          expect(last_response).to have_status_code(200)
          json_response = MultiJson.load(last_response.body)
          expect(json_response).to include({
            'entity' =>  {
              'name' => 'My Updated Service',
              'broker_url' => broker.broker_url,
              'auth_username' => 'new-username',
              'space_guid' => nil,
            },
          })
        end

        context 'when specifying an unknown broker' do
          it 'returns 404' do
            put '/v2/service_brokers/nonexistent', body, headers

            expect(last_response).to have_status_code(HTTP::NOT_FOUND)
          end
        end

        context 'when there is an error in Broker Registration' do
          context 'when the broker url is not a valid http/https url' do
            before { body_hash[:broker_url] = 'foo.bar' }

            it 'returns an error' do
              put "/v2/service_brokers/#{broker.guid}", body, headers

              expect(last_response).to have_status_code(400)
              expect(decoded_response.fetch('code')).to eq(270011)
              expect(decoded_response.fetch('description')).to match(/is not a valid URL/)
            end
          end

          context 'when the broker url is taken' do
            let!(:another_broker) { ServiceBroker.make(broker_url: 'http://example.com') }
            before { body_hash[:broker_url] = another_broker.broker_url }

            it 'returns an error' do
              put "/v2/service_brokers/#{broker.guid}", body, headers

              expect(last_response.status).to eq(400)
              expect(decoded_response.fetch('code')).to eq(270003)
              expect(decoded_response.fetch('description')).to match(/The service broker url is taken/)
            end
          end

          context 'when the broker name is taken' do
            let!(:another_broker) { ServiceBroker.make(broker_url: 'http://example.com') }
            before { body_hash[:name] = another_broker.name }

            it 'returns an error' do
              put "/v2/service_brokers/#{broker.guid}", body, headers

              expect(last_response.status).to eq(400)
              expect(decoded_response.fetch('code')).to eq(270002)
              expect(decoded_response.fetch('description')).to match(/The service broker name is taken/)
            end
          end
        end

        context 'when the broker registration has warnings' do
          let(:catalog_json) do
            {
              'services' => [{
                  'name' => 'fake-service',
                  'id' => 'f479b64b-7c25-42e6-8d8f-e6d22c456c9b',
                  'description' => 'fake service',
                  'tags' => ['no-sql', 'relational'],
                  'max_db_per_node' => 5,
                  'bindable' => true,
                  'metadata' => {
                    'provider' => { 'name' => 'The name' },
                    'listing' => {
                      'imageUrl' => 'http://catgifpage.com/cat.gif',
                      'blurb' => 'fake broker that is fake',
                      'longDescription' => 'A long time ago, in a galaxy far far away...'
                    },
                    'displayName' => 'The Fake Broker'
                  },
                  'dashboard_client' => nil,
                  'plan_updateable' => true,
                  'plans' => [{
                      'name' => 'fake-plan-2',
                      'id' => 'fake-plan-2-guid',
                      'description' => 'Shared fake Server, 5tb persistent disk, 40 max concurrent connections',
                      'max_storage_tb' => 5,
                      'metadata' => {
                        'cost' => 0.0,
                        'bullets' => [
                          { 'content' => 'Shared fake server' },
                          { 'content' => '5 TB storage' },
                          { 'content' => '40 concurrent connections' }
                        ],
                      },
                    }],
                }],
            }
          end
          let(:service) { Service.make(:v2, service_broker: broker) }
          let(:service_plan) { ServicePlan.make(:v2, service: service) }

          before do
            ManagedServiceInstance.make(:v2, service_plan: service_plan)
          end

          it 'includes the warnings in the response' do
            put("/v2/service_brokers/#{broker.guid}", body, headers)
            warnings = last_response.headers['X-Cf-Warnings'].split(',').map { |w| CGI.unescape(w) }
            expect(warnings.length).to eq(1)
            expect(warnings[0]).to match(/Service plans are missing from the broker/)
          end
        end

        describe 'authentication' do
          it 'returns a forbidden status for non-admin users' do
            put "/v2/service_brokers/#{broker.guid}", body, non_admin_headers
            expect(last_response).to be_forbidden
          end
        end
      end
    end
  end
end
