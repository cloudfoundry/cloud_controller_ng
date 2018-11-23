require 'spec_helper'

RSpec.describe 'V3 service brokers' do
  describe 'getting a list of service brokers' do
    it 'pagninates lists of service brokers' do
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

      before(:each) do
        get('/v3/service_brokers', {}, admin_headers)
      end

      it 'returns 200 OK and a body containing all the brokers' do
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
    end

    context 'fetching brokers as a non-admin user' do
      let(:user) { VCAP::CloudController::User.make }
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let!(:object) { VCAP::CloudController::ServiceBroker.make }
      let!(:broker_with_space) { VCAP::CloudController::ServiceBroker.make space: space }

      context 'the user is a space developer' do
        before(:each) do
          set_current_user(user)
          org.add_user(user)
          space.add_developer(user)

          get('/v3/service_brokers', {}, headers_for(user))
        end

        it 'only returns brokers visible to the user' do
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body.fetch('resources').length).to eq(1)
          expect(parsed_body.fetch('resources').first.fetch('guid')).to eq(broker_with_space.guid)
        end
      end

      context 'the user is an org/space auditor/manager/billing manager' do
        before(:each) do
          set_current_user(user)
          org.add_user(user)
          org.add_auditor(user)
          org.add_manager(user)
          org.add_billing_manager(user)
          space.add_auditor(user)
          space.add_manager(user)

          get('/v3/service_brokers', {}, headers_for(user))
        end

        it 'returns no brokers' do
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body.fetch('resources').length).to eq(0)
        end
      end
    end
  end
end
