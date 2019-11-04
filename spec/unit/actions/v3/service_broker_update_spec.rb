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
          state: state
        )
      }

      let(:state) { ServiceBrokerStateEnum::AVAILABLE }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_broker_event_with_request)
        dbl
      end

      subject(:action) {
        V3::ServiceBrokerUpdate.new(existing_service_broker, event_repository)
      }

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

      let(:service_broker_update_request) {
        ServiceBrokerUpdateRequest.find(service_broker_id: existing_service_broker.id)
      }

      it 'does not update the broker in the DB' do
        action.update(message)

        expect(existing_service_broker.name).to eq('old-name')
        expect(existing_service_broker.broker_url).to eq('http://example.org/old-broker-url')
        expect(existing_service_broker.auth_username).to eq('old-admin')
        expect(existing_service_broker.auth_password).to eq('not-welcome')
      end

      it 'creates an entry for the update request in the DB' do
        action.update(message)

        service_broker_update_request = ServiceBrokerUpdateRequest.find(service_broker_id: existing_service_broker.id)

        expect(service_broker_update_request.name).to eq('new-name')
        expect(service_broker_update_request.broker_url).to eq('http://example.org/new-broker-url')
        expect(service_broker_update_request.authentication).to eq('{"credentials":{"username":"new-admin","password":"welcome"}}')
      end

      it 'creates and returns a update job' do
        job = action.update(message)[:pollable_job]

        expect(job).to be_a PollableJobModel
        expect(job.operation).to eq('service_broker.update')
        expect(job.resource_guid).to eq(existing_service_broker.guid)
        expect(job.resource_type).to eq('service_brokers')
      end

      it 'creates an update job with the right arguments' do
        allow(VCAP::CloudController::V3::UpdateBrokerJob).to receive(:new).and_return(spy(VCAP::CloudController::V3::UpdateBrokerJob))
        previous_state = existing_service_broker.service_broker_state.state

        action.update(message)

        expect(VCAP::CloudController::V3::UpdateBrokerJob).to have_received(:new).with(
          service_broker_update_request.guid,
            existing_service_broker.guid,
            previous_state
        ).once
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

      context 'If broker is in transitional state' do
        let(:expected_error_message) { 'Cannot update a broker when other operation is already in progress' }

        context 'If broker is in SYNCHRONIZING state' do
          let(:state) { ServiceBrokerStateEnum::SYNCHRONIZING }

          it 'raises an InvalidServiceBroker error' do
            expect { action.update(message) }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, expected_error_message)
          end
        end

        context 'If broker is in DELETE_IN_PROGRESS state' do
          let(:state) { ServiceBrokerStateEnum::DELETE_IN_PROGRESS }

          it 'raises an InvalidServiceBroker error' do
            expect { action.update(message) }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, expected_error_message)
          end
        end
      end

      context 'If broker is in a failed state' do
        context 'If broker is in SYNCHRONIZATION_FAILED state' do
          let(:state) { ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED }

          it 'does not raise an error' do
            expect { action.update(message) }.not_to raise_error
          end
        end

        context 'If broker is in DELETE_FAILED state' do
          let(:state) { ServiceBrokerStateEnum::DELETE_FAILED }

          it 'does not raise an error' do
            expect { action.update(message) }.not_to raise_error
          end
        end
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
          expect(job.operation).to eq('service_broker.update')
          expect(job.resource_guid).to eq(existing_service_broker.guid)
          expect(job.resource_type).to eq('service_brokers')
        end

        it 'creates an update job with the right arguments' do
          allow(VCAP::CloudController::V3::UpdateBrokerJob).to receive(:new).and_return(spy(VCAP::CloudController::V3::UpdateBrokerJob))

          action.update(message)

          expect(VCAP::CloudController::V3::UpdateBrokerJob).to have_received(:new).with(
            service_broker_update_request.guid,
              existing_service_broker.guid,
              nil
          ).once
        end
      end
    end
  end
end
