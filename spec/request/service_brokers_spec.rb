require 'spec_helper'

RSpec.describe 'V3 service brokers' do
  context 'as an admin user' do
    describe 'getting a single service broker' do
      context 'when there are no service brokers' do
        before(:each) do
          get('/v3/service_brokers/does-not-exist', {}, admin_headers)
        end

        it 'responds with 404 Not Found' do
          expect(last_response.status).to eq(404)
        end
      end

      context 'when there is a service broker' do
        let!(:service_broker) {
          VCAP::CloudController::ServiceBroker.make(name: 'test-broker',
                                                    broker_url: 'http://test-broker.example.com')
        }

        before(:each) do
          get("/v3/service_brokers/#{service_broker.guid}", {}, admin_headers)
        end

        let(:parsed_body) {
          JSON.parse(last_response.body)
        }

        let(:returned_service_broker) {
          parsed_body
        }

        it 'returns 200 OK and a body containing the single broker' do
          expect(last_response).to have_status_code(200)

          expect(parsed_body).not_to be_nil
        end

        describe 'the returned service broker' do
          it 'contains the guid' do
            expect(returned_service_broker.fetch('guid')).to eq(service_broker.guid)
          end

          it 'contains the name' do
            expect(returned_service_broker.fetch('name')).to eq(service_broker.name)
          end

          it 'contains the url' do
            expect(returned_service_broker.fetch('url')).to eq(service_broker.broker_url)
          end

          it 'contains the datetimes' do
            expect(returned_service_broker.fetch('created_at')).to eq(service_broker.created_at.iso8601)
            expect(returned_service_broker.fetch('updated_at')).to eq(service_broker.updated_at.iso8601)
          end

          it 'contains a link to itself' do
            expect(returned_service_broker).to have_key('links')
            expect(returned_service_broker['links']).to have_key('self')
            expect(returned_service_broker['links']['self'].fetch('href')).to include("/v3/service_brokers/#{service_broker.guid}")
          end

          context 'when the broker is not space scoped' do
            it 'contains no relationships' do
              expect(returned_service_broker.fetch('relationships').length).to eq(0)
            end

            it 'contains no space in links' do
              expect(returned_service_broker['links']).not_to have_key('space')
            end
          end

          context 'when the broker is space scoped' do
            let(:space) { VCAP::CloudController::Space.make }
            let!(:service_broker) {
              VCAP::CloudController::ServiceBroker.make(name: 'test-space-scoped-broker',
                                                        broker_url: 'http://test-space-scoped-broker.example.com',
                                                        space: space)
            }

            it 'there is a relationships field with key called space' do
              expect(returned_service_broker).to have_key('relationships')
              expect(returned_service_broker['relationships']).to have_key('space')
              expect(returned_service_broker['relationships']['space']).to have_key('data')
              expect(returned_service_broker['relationships']['space']['data'].fetch('guid')).to eq(space.guid)
            end

            it 'there is a links field with key called space' do
              expect(returned_service_broker).to have_key('links')
              expect(returned_service_broker['links']).to have_key('space')
              expect(returned_service_broker['links']['space'].fetch('href')).to include("/v3/spaces/#{space.guid}")
            end
          end
        end
      end
    end

    describe 'getting a list of service brokers' do
      it 'paginates lists of service brokers' do
        get('/v3/service_brokers', {}, admin_headers)

        json_body = JSON.parse(last_response.body)
        expect(json_body).to have_key('pagination')
      end

      context 'when there are no service brokers' do
        it 'returns 200 OK and a body with no service brokers' do
          get('/v3/service_brokers', {}, admin_headers)

          expect(last_response).to have_status_code(200)

          json_body = JSON.parse(last_response.body)
          expect(json_body).to have_key('resources')
          expect(json_body['resources'].length).to eq(0)
        end
      end

      context 'when there is a service broker' do
        let!(:service_broker) {
          VCAP::CloudController::ServiceBroker.make(name: 'test-broker',
                                                    broker_url: 'http://test-broker.example.com')
        }

        before(:each) do
          get('/v3/service_brokers', {}, admin_headers)
        end

        let(:parsed_body) {
          JSON.parse(last_response.body)
        }

        let(:returned_service_broker) {
          parsed_body.fetch('resources').first
        }

        it 'returns 200 OK and a body containing the single broker' do
          expect(last_response).to have_status_code(200)

          expect(parsed_body.fetch('resources').length).to eq(1)
        end

        describe 'the returned service broker' do
          it 'contains the guid' do
            expect(returned_service_broker.fetch('guid')).to eq(service_broker.guid)
          end

          it 'contains the name' do
            expect(returned_service_broker.fetch('name')).to eq(service_broker.name)
          end

          it 'contains the url' do
            expect(returned_service_broker.fetch('url')).to eq(service_broker.broker_url)
          end

          it 'contains the datetimes' do
            expect(returned_service_broker.fetch('created_at')).to eq(service_broker.created_at.iso8601)
            expect(returned_service_broker.fetch('updated_at')).to eq(service_broker.updated_at.iso8601)
          end

          it 'contains a link to itself' do
            expect(returned_service_broker).to have_key('links')
            expect(returned_service_broker['links']).to have_key('self')
            expect(returned_service_broker['links']['self'].fetch('href')).to include("/v3/service_brokers/#{service_broker.guid}")
          end

          context 'when the broker is not space scoped' do
            it 'contains no relationships' do
              expect(returned_service_broker.fetch('relationships').length).to eq(0)
            end

            it 'contains no space in links' do
              expect(returned_service_broker['links']).not_to have_key('space')
            end
          end

          context 'when the broker is space scoped' do
            let(:space) { VCAP::CloudController::Space.make }
            let!(:service_broker) {
              VCAP::CloudController::ServiceBroker.make(name: 'test-space-scoped-broker',
                                                        broker_url: 'http://test-space-scoped-broker.example.com',
                                                        space: space)
            }

            it 'there is a relationships field with key called space' do
              expect(returned_service_broker).to have_key('relationships')
              expect(returned_service_broker['relationships']).to have_key('space')
              expect(returned_service_broker['relationships']['space']).to have_key('data')
              expect(returned_service_broker['relationships']['space']['data'].fetch('guid')).to eq(space.guid)
            end

            it 'there is a links field with key called space' do
              expect(returned_service_broker).to have_key('links')
              expect(returned_service_broker['links']).to have_key('space')
              expect(returned_service_broker['links']['space'].fetch('href')).to include("/v3/spaces/#{space.guid}")
            end
          end
        end
      end

      context 'when there are multiple service brokers' do
        let!(:service_broker1) {
          VCAP::CloudController::ServiceBroker.make(name: 'test-broker-1',
                                                    broker_url: 'http://test-broker-1.example.com')
        }

        let(:space) { VCAP::CloudController::Space.make }
        let!(:service_broker2) {
          VCAP::CloudController::ServiceBroker.make(name: 'test-broker-2',
                                                    broker_url: 'http://test-broker-2.example.com',
                                                    space: space)
        }

        it 'returns 200 OK and a body containing all the brokers' do
          get('/v3/service_brokers', {}, admin_headers)
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body.fetch('resources').length).to eq(2)
          expect(parsed_body.fetch('resources').first.fetch('name')).to eq('test-broker-1')
          expect(parsed_body.fetch('resources').second.fetch('name')).to eq('test-broker-2')
        end

        context 'when requesting one broker per page' do
          before(:each) do
            get('/v3/service_brokers?per_page=1', {}, admin_headers)
          end

          it 'returns 200 OK and a body containing one broker with pagination information for the next' do
            expect(last_response).to have_status_code(200)

            parsed_body = JSON.parse(last_response.body)
            expect(parsed_body.fetch('pagination').fetch('total_results')).to eq(2)
            expect(parsed_body.fetch('pagination').fetch('total_pages')).to eq(2)

            expect(parsed_body.fetch('resources').length).to eq(1)
          end
        end

        context 'when requesting with a specific order by name' do
          context 'in ascending order' do
            before(:each) do
              get('/v3/service_brokers?order_by=name', {}, admin_headers)
            end

            it 'returns 200 OK and a body containg the brokers ordered by created at time' do
              expect(last_response).to have_status_code(200)

              parsed_body = JSON.parse(last_response.body)

              expect(parsed_body.fetch('resources').length).to eq(2)
              expect(parsed_body.fetch('resources').first.fetch('name')).to eq('test-broker-1')
              expect(parsed_body.fetch('resources').last.fetch('name')).to eq('test-broker-2')
            end
          end

          context 'descending order' do
            before(:each) do
              get('/v3/service_brokers?order_by=-name', {}, admin_headers)
            end

            it 'returns 200 OK and a body containg the brokers ordered by created at time' do
              expect(last_response).to have_status_code(200)

              parsed_body = JSON.parse(last_response.body)

              expect(parsed_body.fetch('resources').length).to eq(2)
              expect(parsed_body.fetch('resources').first.fetch('name')).to eq('test-broker-2')
              expect(parsed_body.fetch('resources').last.fetch('name')).to eq('test-broker-1')
            end
          end
        end

        context 'when requesting with a space guid filter' do
          before(:each) do
            get("/v3/service_brokers?space_guids=#{space.guid}", {}, admin_headers)
          end

          it 'returns 200 OK and a body containing one broker matching the space guid filter' do
            expect(last_response).to have_status_code(200)

            parsed_body = JSON.parse(last_response.body)

            expect(parsed_body.fetch('resources').length).to eq(1)
            expect(parsed_body.fetch('resources').first.fetch('name')).to eq('test-broker-2')
          end
        end

        context 'when requesting with a space guid filter for a random space guid' do
          before(:each) do
            get('/v3/service_brokers?space_guids=random-space-guid', {}, admin_headers)
          end

          it 'returns 200 OK and a body containing no broker' do
            expect(last_response).to have_status_code(200)

            parsed_body = JSON.parse(last_response.body)

            expect(parsed_body.fetch('resources').length).to eq(0)
          end
        end

        context 'when requesting with a names filter' do
          before(:each) do
            get("/v3/service_brokers?names=#{service_broker1.name}", {}, admin_headers)
          end

          it 'returns 200 OK and a body containing one broker matching the names filter' do
            expect(last_response).to have_status_code(200)

            parsed_body = JSON.parse(last_response.body)

            expect(parsed_body.fetch('resources').length).to eq(1)
            expect(parsed_body.fetch('resources').first.fetch('name')).to eq(service_broker1.name)
          end
        end
      end
    end

    describe 'registering a global service broker' do
      before(:each) do
        catalog = FakeServiceBrokerV2Client.new.catalog

        stub_request(:get, 'http://example.org/broker-url/v2/catalog').
          to_return(status: 200, body: catalog.to_json, headers: {})

        post('/v3/service_brokers', {
          name: 'broker name',
          url: 'http://example.org/broker-url',
          username: 'admin',
          password: 'welcome',
        }.to_json, admin_headers)
      end

      it 'returns 201 Created' do
        expect(last_response).to have_status_code(201)
      end

      it 'creates a service broker entity' do
        expect(VCAP::CloudController::ServiceBroker.count).to eq(1)

        service_broker = VCAP::CloudController::ServiceBroker.last
        expect(service_broker).to include(
          'name' => 'broker name',
          'broker_url' => 'http://example.org/broker-url',
          'auth_username' => 'admin',
          'space_guid' => nil,
        )
        expect(service_broker.auth_password).to eq('welcome') # password not exported in to_hash
      end

      it 'synchronizes services and plans' do
        service_broker = VCAP::CloudController::ServiceBroker.last
        service = VCAP::CloudController::Service.where(service_broker_id: service_broker.id).first
        expect(service).to include(
          'label' => 'service_name',
        )
        plan = VCAP::CloudController::ServicePlan.where(service_id: service.id).first
        expect(plan).to include(
          'name' => 'fake_plan_name',
        )
      end

      it 'reports service events' do
        events = VCAP::CloudController::Event.all
        expect(events).to have(2).items
        expect(events[0]).to include('type' => 'audit.service.create', 'actor_name' => 'broker name')
        expect(events[1]).to include('type' => 'audit.service_plan.create', 'actor_name' => 'broker name')
      end
    end
  end

  context 'as a non-admin user who is a space developer' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let!(:object) { VCAP::CloudController::ServiceBroker.make }

    let!(:broker_with_space) { VCAP::CloudController::ServiceBroker.make space: space }
    let!(:broker_non_spaced) { VCAP::CloudController::ServiceBroker.make }

    before(:each) do
      set_current_user(user)
      org.add_user(user)
      space.add_developer(user)
    end

    describe 'getting a single service broker' do
      let(:parsed_body) {
        JSON.parse(last_response.body)
      }

      let(:returned_service_broker) {
        parsed_body
      }

      context 'when requested broker is space-scoped' do
        before(:each) do
          get("/v3/service_brokers/#{broker_with_space.guid}", {}, headers_for(user))
        end

        it 'returns 200 OK and a body containing the single broker' do
          expect(last_response).to have_status_code(200)

          expect(parsed_body).not_to be_nil

          expect(returned_service_broker['guid']).to eq(broker_with_space.guid)
        end
      end

      context 'when requested broker is not space-scoped' do
        before(:each) do
          get("/v3/service_brokers/#{broker_non_spaced.guid}", {}, headers_for(user))
        end

        it 'responds with 404 Not Found' do
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'getting a list of service brokers' do
      it 'only returns brokers visible to the user' do
        get('/v3/service_brokers', {}, headers_for(user))

        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body.fetch('resources').length).to eq(1)
        expect(parsed_body.fetch('resources').first.fetch('guid')).to eq(broker_with_space.guid)
      end
    end

    describe 'registering a global service broker' do
      it 'fails authorization' do
        response = post('/v3/service_brokers', {
          name: 'broker name',
          url: 'http://example.org/broker-url',
          username: 'admin',
          password: 'welcome',
        }.to_json, headers_for(user))

        expect(response).to have_status_code(403)
      end
    end
  end

  context 'as a non-admin user who is an org/space auditor/manager/billing manager' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let!(:object) { VCAP::CloudController::ServiceBroker.make }

    let!(:broker_with_space) { VCAP::CloudController::ServiceBroker.make space: space }
    let!(:broker_non_spaced) { VCAP::CloudController::ServiceBroker.make }

    before(:each) do
      set_current_user(user)
      org.add_user(user)
      org.add_auditor(user)
      org.add_manager(user)
      org.add_billing_manager(user)
      space.add_auditor(user)
      space.add_manager(user)
    end

    describe 'getting a single service broker' do
      context 'when requested broker is space-scoped' do
        before(:each) do
          get("/v3/service_brokers/#{broker_with_space.guid}", {}, headers_for(user))
        end

        it 'responds with 404 Not Found' do
          expect(last_response.status).to eq(404)
        end
      end

      context 'when requested broker is not space-scoped' do
        before(:each) do
          get("/v3/service_brokers/#{broker_non_spaced.guid}", {}, headers_for(user))
        end

        it 'responds with 404 Not Found' do
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'getting a list of service brokers' do
      it 'returns no brokers' do
        get('/v3/service_brokers', {}, headers_for(user))

        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body.fetch('resources').length).to eq(0)
      end
    end

    describe 'registering a global service broker' do
      it 'fails authorization' do
        response = post('/v3/service_brokers', {
          name: 'broker name',
          url: 'http://example.org/broker-url',
          username: 'admin',
          password: 'welcome',
        }.to_json, headers_for(user))

        expect(response).to have_status_code(403)
      end
    end
  end
end
