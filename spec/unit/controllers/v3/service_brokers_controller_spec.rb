require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe ServiceBrokersController, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make, email: 'joe@example.org') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:space_guid) { space.guid }
  let(:relationships_part) { {} }

  describe '#create' do
    let(:request_body) {
      {
          name: 'some-name',
          url: 'https://fake.url',
          credentials: {
              type: 'basic',
              data: {
                  username: 'fake username',
                  password: 'fake password',
              },
          },
      }.merge(relationships_part)
    }

    context 'when there are no relationships' do
      before do
        allow_user_global_read_access(user)
        allow_user_global_write_access(user)

        post :create, params: request_body, as: :json
      end

      let(:broker) { VCAP::CloudController::ServiceBroker.last }
      let(:job) { VCAP::CloudController::PollableJobModel.last }

      it 'emits an audit event' do
        events = VCAP::CloudController::Event.all.map { |e| { type: e.type, actor: e.actor_name, metadata: e.metadata } }
        expect(events).to eq([
          {
              type: 'audit.service_broker.create',
              actor: 'joe@example.org',
              metadata: {
                  'request' => {
                      'name' => 'some-name',
                      'broker_url' => 'https://fake.url',
                      'auth_username' => 'fake username',
                      'auth_password' => '[REDACTED]'
                  }
              }
          },
        ])
      end
    end

    context 'when there is a space relationship' do
      let(:relationships_part) { { relationships: { space: { data: { guid: space_guid } } } } }

      before do
        allow_user_read_access_for(user, spaces: [space])
        allow_user_write_access(user, space: space)
        post :create, params: request_body, as: :json
      end

      it 'responds with 202 Accepted and creates a space-scoped broker' do
        expect(response).to have_status_code(202)

        broker = VCAP::CloudController::ServiceBroker.last
        expect(broker.name).to eq(request_body[:name])
        expect(broker.broker_url).to eq(request_body[:url])
        expect(broker.auth_username).to eq(request_body.dig(:credentials, :data, :username))
        expect(broker.auth_password).to eq(request_body.dig(:credentials, :data, :password))
        expect(broker.space.guid).to eq(request_body.dig(:relationships, :space, :data, :guid))
      end

      it 'emits an audit event' do
        events = VCAP::CloudController::Event.all.map { |e| { type: e.type, actor: e.actor_name, metadata: e.metadata } }
        expect(events).to eq([
          {
              type: 'audit.service_broker.create',
              actor: 'joe@example.org',
              metadata: {
                  'request' => {
                      'name' => 'some-name',
                      'broker_url' => 'https://fake.url',
                      'auth_username' => 'fake username',
                      'auth_password' => '[REDACTED]',
                      'space_guid' => space_guid
                  }
              }
          },
        ])
      end

      context 'when a non-existent space is provided' do
        let(:space_guid) { 'space-that-does-not-exist' }

        it 'returns a error saying the space is invalid' do
          expect(response).to have_status_code(422)
          expect(response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
        end
      end

      context 'when a space is provided that the user cannot read' do
        let(:space_with_no_read_access) { VCAP::CloudController::Space.make }
        let(:space_guid) { space_with_no_read_access.guid }

        it 'returns a error saying the space is invalid' do
          expect(response).to have_status_code(422)
          expect(response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
        end
      end
    end
  end

  describe '#destroy' do
    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }

    before do
      allow_user_global_read_access(user)
      allow_user_global_write_access(user)
      stub_delete(service_broker)
    end

    context 'when there are no service instances' do
      it 'returns a 204' do
        delete :destroy, params: { guid: service_broker.guid }
        expect(response.status).to eq 204
        expect(service_broker.exists?).to be_falsey
      end
    end

    context 'when there are service instances' do
      let(:service) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }

      before do
        VCAP::CloudController::ServiceInstance.make(space: space, service_plan_id: service_plan.id)
      end

      it 'returns a 422 and do not delete the broker' do
        delete :destroy, params: { guid: service_broker.guid }
        expect(response.status).to eq 422
        expect(service_broker.exists?).to be_truthy
      end
    end

    context 'permissions' do
      context 'when the service broker does not exist' do
        it 'returns a 404' do
          delete :destroy, params: { guid: 'a-guid-that-doesnt-exist' }
          expect(response).to have_status_code(404)
          expect(response.body).to include 'Service broker not found'
        end
      end

      context 'global brokers' do
        context 'when the user has read, but not write permissions' do
          before do
            allow_user_global_read_access(user)
            disallow_user_global_write_access(user)
          end

          it 'returns a 403 Not Authorized and does NOT delete the broker' do
            delete :destroy, params: { guid: service_broker.guid }

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
            expect(service_broker.exists?).to be_truthy
          end
        end

        context 'when the user does not have read permissions' do
          before do
            disallow_user_global_read_access(user)
          end

          it 'returns a 404 and does NOT delete the broker' do
            delete :destroy, params: { guid: service_broker.guid }

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Service broker not found'
            expect(service_broker.exists?).to be_truthy
          end
        end
      end

      context 'space scoped brokers' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }

        before do
          stub_delete(service_broker)
        end

        context 'when the user has read, but not write permissions on the space' do
          before do
            allow_user_read_access_for(user, spaces: [space])
            disallow_user_write_access(user, space: space)
          end

          it 'returns a 403 Not Authorized and does NOT delete the broker' do
            delete :destroy, params: { guid: service_broker.guid }

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
            expect(service_broker.exists?).to be_truthy
          end
        end

        context 'when the user does not have read permissions on the space' do
          before do
            disallow_user_read_access(user, space: space)
          end

          it 'returns a 404 and does NOT delete the broker' do
            delete :destroy, params: { guid: service_broker.guid }

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
            expect(response.body).to include 'Service broker not found'
            expect(service_broker.exists?).to be_truthy
          end
        end
      end
    end
  end
end
