require 'spec_helper'
require 'actions/v3/service_broker_update'

module VCAP
  module CloudController
    RSpec.describe 'ServiceBrokerUpdate' do
      let!(:existing_service_broker) do
        ServiceBroker.make(
          name: 'old-name',
          broker_url: 'http://example.org/old-broker-url',
          auth_username: 'old-admin',
          auth_password: 'not-welcome'
        )
      end

      let!(:service_broker_state) {
        ServiceBrokerState.make(
          service_broker_id: existing_service_broker.id,
          state: ServiceBrokerStateEnum::AVAILABLE
        )
      }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_broker_event_with_request)
        dbl
      end

      subject(:action) { V3::ServiceBrokerUpdate.new(existing_service_broker, event_repository) }

      let(:message) do
        ServiceBrokerUpdateMessage.new(
          name: 'new-name',
          url: 'http://example.org/new-broker-url',
          authentication: {
            credentials: {
              username: 'new-admin',
              password: 'welcome'
            }
          }
        )
      end

      it 'updates the broker' do
        action.update(message)

        expect(existing_service_broker.name).to eq('new-name')
        expect(existing_service_broker.broker_url).to eq('http://example.org/new-broker-url')
        expect(existing_service_broker.auth_username).to eq('new-admin')
        expect(existing_service_broker.auth_password).to eq('welcome')
      end

      it 'creates and returns a synchronization job' do
        job = action.update(message)[:pollable_job]

        expect(job).to be_a PollableJobModel
        expect(job.operation).to eq('service_broker.catalog.synchronize')
        expect(job.resource_guid).to eq(existing_service_broker.guid)
        expect(job.resource_type).to eq('service_brokers')
      end

      it 'sets the state to SYNCHRONIZING' do
        action.update(message)

        expect(existing_service_broker.service_broker_state.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
      end

      it 'creates an audit event' do
        action.update(message)

        expect(event_repository).
          to have_received(:record_broker_event_with_request).with(
            :update,
            instance_of(ServiceBroker),
            {
              name: 'new-name',
              url: 'http://example.org/new-broker-url',
              authentication: {
                credentials: {
                  username: 'new-admin',
                  password: '[PRIVATE DATA HIDDEN]'
                }
              }
            }.with_indifferent_access
          )
      end

      context 'legacy service brokers' do
        let!(:service_broker_state) {} # broker creating from V2 endpoint will not have a state

        it 'sets the state to SYNCHRONIZING' do
          action.update(message)

          expect(existing_service_broker.reload.service_broker_state.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
        end

        it 'creates and returns a synchronization job' do
          job = action.update(message)[:pollable_job]

          expect(job).to be_a PollableJobModel
          expect(job.operation).to eq('service_broker.catalog.synchronize')
          expect(job.resource_guid).to eq(existing_service_broker.guid)
          expect(job.resource_type).to eq('service_brokers')
        end
      end

      describe 'partial updates' do
        it 'updates the name' do
          message = ServiceBrokerUpdateMessage.new(name: 'new-name')
          action.update(message)

          expect(existing_service_broker.name).to eq('new-name')
          expect(existing_service_broker.broker_url).to eq('http://example.org/old-broker-url')
          expect(existing_service_broker.auth_username).to eq('old-admin')
          expect(existing_service_broker.auth_password).to eq('not-welcome')
        end

        it 'updates the url' do
          message = ServiceBrokerUpdateMessage.new(url: 'http://example.org/new-broker-url')

          action.update(message)

          expect(existing_service_broker.name).to eq('old-name')
          expect(existing_service_broker.broker_url).to eq('http://example.org/new-broker-url')
          expect(existing_service_broker.auth_username).to eq('old-admin')
          expect(existing_service_broker.auth_password).to eq('not-welcome')
        end

        it 'updates the authentication' do
          message = ServiceBrokerUpdateMessage.new(
            authentication: {
              credentials: {
                username: 'new-admin',
                password: 'welcome'
              }
            }
          )

          action.update(message)

          expect(existing_service_broker.name).to eq('old-name')
          expect(existing_service_broker.broker_url).to eq('http://example.org/old-broker-url')
          expect(existing_service_broker.auth_username).to eq('new-admin')
          expect(existing_service_broker.auth_password).to eq('welcome')
        end
      end

      describe 'when there is a model level validation' do
        before do
          allow_any_instance_of(ServiceBroker).to receive(:validate) do |record|
            record.errors.add(:something, 'is not right')
          end
        end

        it 'fails to update and raises InvalidServiceBroker' do
          expect {
            action.update(message)
          }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, 'something is not right')
        end
      end
    end
  end
end
