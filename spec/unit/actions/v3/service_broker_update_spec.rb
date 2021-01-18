require 'spec_helper'
require 'actions/v3/service_broker_update'
require 'messages/service_broker_update_message'

module VCAP
  module CloudController
    RSpec.describe ServiceBrokerUpdate do
      subject(:action) { V3::ServiceBrokerUpdate.new(existing_service_broker, message, event_repository) }

      let(:message) { ServiceBrokerUpdateMessage.new(request) }

      let(:state) { ServiceBrokerStateEnum::AVAILABLE }
      let!(:existing_service_broker) do
        ServiceBroker.make(
          name: 'old-name',
          broker_url: 'http://example.org/old-broker-url',
          auth_username: 'old-admin',
          auth_password: 'not-welcome',
          state: state
        )
      end

      let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: Sham.guid }) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_broker_event_with_request)
        allow(dbl).to receive(:user_audit_info).and_return(user_audit_info)
        dbl
      end

      describe '#update_broker_needed?' do
        context 'name' do
          let(:request) { { name: 'new-name' } }

          it 'is true' do
            expect(action.update_broker_needed?).to be_truthy
          end
        end

        context 'metadata' do
          let(:request) do
            {
              metadata: {
                labels: { potato: 'yam' },
                annotations: { style: 'mashed' }
              }
            }
          end

          it 'is false' do
            expect(action.update_broker_needed?).to be_falsey
          end
        end

        context 'url' do
          let(:request) { { url: 'new-url' } }

          it 'is true' do
            expect(action.update_broker_needed?).to be_truthy
          end
        end

        context 'authentication' do
          let(:request) do
            {
              authentication: {
                credentials: {
                  username: 'new-admin',
                  password: 'welcome'
                }
              }
            }
          end

          it 'is true' do
            expect(action.update_broker_needed?).to be_truthy
          end
        end
      end

      describe '#update_sync' do
        let(:request) do
          {
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            }
          }
        end

        before do
          action.update_sync
        end

        it 'updates metadata' do
          expect(existing_service_broker).to have_labels({ key: 'potato', value: 'yam' })
          expect(existing_service_broker).to have_annotations({ key: 'style', value: 'mashed' })
        end
      end

      describe '#enqueue_update' do
        let(:request) do
          {
            name: 'new-name',
            url: 'http://example.org/new-broker-url',
            authentication: {
              credentials: {
                username: 'new-admin',
                password: 'welcome'
              }
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            }
          }
        end

        let(:service_broker_update_request) {
          ServiceBrokerUpdateRequest.find(service_broker_id: existing_service_broker.id)
        }

        it 'does not update the broker in the DB' do
          action.enqueue_update

          expect(existing_service_broker.name).to eq('old-name')
          expect(existing_service_broker.broker_url).to eq('http://example.org/old-broker-url')
          expect(existing_service_broker.auth_username).to eq('old-admin')
          expect(existing_service_broker.auth_password).to eq('not-welcome')
        end

        it 'creates an entry for the update request in the DB' do
          action.enqueue_update

          service_broker_update_request = ServiceBrokerUpdateRequest.find(service_broker_id: existing_service_broker.id)

          expect(service_broker_update_request.name).to eq('new-name')
          expect(service_broker_update_request.broker_url).to eq('http://example.org/new-broker-url')
          expect(service_broker_update_request.authentication).to eq('{"credentials":{"username":"new-admin","password":"welcome"}}')
          expect(service_broker_update_request.labels[0][:key_name]).to eq('potato')
          expect(service_broker_update_request.labels[0][:value]).to eq('yam')
          expect(service_broker_update_request.annotations[0][:key]).to eq('style')
          expect(service_broker_update_request.annotations[0][:value]).to eq('mashed')
        end

        it 'creates and returns a update job' do
          job = action.enqueue_update

          expect(job).to be_a PollableJobModel
          expect(job.operation).to eq('service_broker.update')
          expect(job.resource_guid).to eq(existing_service_broker.guid)
          expect(job.resource_type).to eq('service_brokers')
        end

        it 'creates an update job with the right arguments' do
          allow(VCAP::CloudController::V3::UpdateBrokerJob).to receive(:new).and_return(spy(VCAP::CloudController::V3::UpdateBrokerJob))
          previous_state = existing_service_broker.state

          action.enqueue_update

          expect(VCAP::CloudController::V3::UpdateBrokerJob).to have_received(:new).with(
            service_broker_update_request.guid,
            existing_service_broker.guid,
            previous_state,
            user_audit_info: user_audit_info
          ).once
        end

        it 'sets the state to SYNCHRONIZING' do
          action.enqueue_update

          expect(existing_service_broker.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
        end

        it 'creates an audit event' do
          action.enqueue_update

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
                },
                metadata: {
                  labels: { potato: 'yam' },
                  annotations: { style: 'mashed' }
                }
              }.with_indifferent_access
            )
        end

        context 'If broker is in transitional state' do
          let(:expected_error_message) { 'Cannot update a broker when other operation is already in progress' }

          context 'If broker is in SYNCHRONIZING state' do
            let(:state) { ServiceBrokerStateEnum::SYNCHRONIZING }

            it 'raises an InvalidServiceBroker error' do
              expect { action.enqueue_update }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, expected_error_message)
            end
          end

          context 'If broker is in DELETE_IN_PROGRESS state' do
            let(:state) { ServiceBrokerStateEnum::DELETE_IN_PROGRESS }

            it 'raises an InvalidServiceBroker error' do
              expect { action.enqueue_update }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, expected_error_message)
            end
          end
        end

        context 'If broker is in a failed state' do
          context 'If broker is in SYNCHRONIZATION_FAILED state' do
            let(:state) { ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED }

            it 'does not raise an error' do
              expect { action.enqueue_update }.not_to raise_error
            end
          end

          context 'If broker is in DELETE_FAILED state' do
            let(:state) { ServiceBrokerStateEnum::DELETE_FAILED }

            it 'does not raise an error' do
              expect { action.enqueue_update }.not_to raise_error
            end
          end
        end

        context 'legacy service brokers' do
          let!(:state) { '' } # broker creating from V2 endpoint will not have a state

          it 'sets the state to SYNCHRONIZING' do
            action.enqueue_update

            expect(existing_service_broker.reload.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
          end

          it 'creates and returns a synchronization job' do
            job = action.enqueue_update

            expect(job).to be_a PollableJobModel
            expect(job.operation).to eq('service_broker.update')
            expect(job.resource_guid).to eq(existing_service_broker.guid)
            expect(job.resource_type).to eq('service_brokers')
          end

          it 'creates an update job with the right arguments' do
            allow(VCAP::CloudController::V3::UpdateBrokerJob).to receive(:new).and_return(spy(VCAP::CloudController::V3::UpdateBrokerJob))

            action.enqueue_update

            expect(VCAP::CloudController::V3::UpdateBrokerJob).to have_received(:new).with(
              service_broker_update_request.guid,
              existing_service_broker.guid,
              '',
              user_audit_info: user_audit_info
            ).once
          end
        end
      end
    end
  end
end
