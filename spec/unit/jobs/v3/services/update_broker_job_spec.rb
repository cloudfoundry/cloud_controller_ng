require 'rails_helper'
require 'jobs/v3/services/update_broker_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe UpdateBrokerJob do
        it_behaves_like 'delayed job', UpdateBrokerJob

        describe '#perform' do
          let!(:broker) do
            ServiceBroker.create(
              name: 'test-broker',
              broker_url: 'http://example.org/broker-url',
              auth_username: 'username',
              auth_password: 'password'
            )
          end

          let!(:label) {
            ServiceBrokerLabelModel.create(
              service_broker: broker,
              key_name: 'potato',
              value: 'yam'
            )
          }

          let!(:annotation) {
            ServiceBrokerAnnotationModel.create(
              service_broker: broker,
              key: 'style',
              value: 'mashed'
            )
          }

          let(:update_broker_request) do
            ServiceBrokerUpdateRequest.create(
              name: 'new-name',
              broker_url: 'http://example.org/new-broker-url',
              authentication: '{"credentials":{"username":"new-admin","password":"welcome"}}',
              service_broker_id: broker.id
            )
          end

          let!(:update_broker_label_request) {
            ServiceBrokerUpdateRequestLabelModel.create(
              service_broker_update_request: update_broker_request,
              key_name: 'potato',
              value: 'sweet'
            )
          }

          let!(:update_broker_annotation_request) {
            ServiceBrokerUpdateRequestAnnotationModel.create(
              service_broker_update_request: update_broker_request,
              key: 'style',
              value: 'baked'
            )
          }

          let(:service_manager_factory) { Services::ServiceBrokers::ServiceManager }

          let(:previous_state) { ServiceBrokerStateEnum::AVAILABLE }

          let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: Sham.guid }) }

          subject(:job) do
            UpdateBrokerJob.new(update_broker_request.guid, broker.guid, previous_state, user_audit_info: user_audit_info)
          end

          let(:broker_client) { FakeServiceBrokerV2Client.new }

          before do
            allow(Services::ServiceClientProvider).to receive(:provide).
              with(broker: broker).
              and_return(broker_client)

            broker.update(state: ServiceBrokerStateEnum::SYNCHRONIZING)
          end

          it 'updates the service broker and creates the service offerings and plans from the catalog' do
            job.perform

            broker.reload

            expect(broker.name).to eq('new-name')
            expect(broker.broker_url).to eq('http://example.org/new-broker-url')
            expect(broker.auth_username).to eq('new-admin')
            expect(broker.auth_password).to eq('welcome')
            expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)

            expect(broker.labels.size).to eq(1)
            expect(broker.annotations.size).to eq(1)

            expect(broker.labels[0][:key_name]).to eq('potato')
            expect(broker.labels[0][:value]).to eq('sweet')

            expect(broker.annotations[0][:key]).to eq('style')
            expect(broker.annotations[0][:value]).to eq('baked')

            service_offerings = Service.where(service_broker_id: broker.id)
            expect(service_offerings.count).to eq(1)
            expect(service_offerings.first.label).to eq(broker_client.service_name)

            service_plans = ServicePlan.where(service_id: service_offerings.first.id)
            expect(service_plans.count).to eq(1)
            expect(service_plans.first.name).to eq(broker_client.plan_name)

            expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
            expect(ServiceBrokerUpdateRequestLabelModel.where(id: update_broker_request.id).all).to be_empty
            expect(ServiceBrokerUpdateRequestAnnotationModel.where(id: update_broker_request.id).all).to be_empty
          end

          context 'partial updates' do
            subject(:job) do
              UpdateBrokerJob.new(update_broker_request.guid, broker.guid, previous_state)
            end

            let!(:updater_stub) do
              instance_double(VCAP::CloudController::V3::ServiceBrokerCatalogUpdater, {
                refresh: nil
              })
            end

            before do
              allow(VCAP::CloudController::V3::ServiceBrokerCatalogUpdater).to receive(:new).and_return(updater_stub)
            end

            it 'updates the name without refreshing the catalog' do
              update_broker_request = ServiceBrokerUpdateRequest.create(name: 'new-name', service_broker_id: broker.id)
              job = UpdateBrokerJob.new(update_broker_request.guid, broker.guid, previous_state, user_audit_info: user_audit_info)

              job.perform

              broker.reload
              expect(broker.name).to eq('new-name')
              expect(broker.broker_url).to eq('http://example.org/broker-url')
              expect(broker.auth_username).to eq('username')
              expect(broker.auth_password).to eq('password')

              expect(updater_stub).not_to have_received(:refresh)
            end

            it 'updates the url and refreshes the catalog' do
              update_broker_request = ServiceBrokerUpdateRequest.create(
                broker_url: 'http://example.org/new-broker-url',
                service_broker_id: broker.id
              )
              job = UpdateBrokerJob.new(update_broker_request.guid, broker.guid, previous_state, user_audit_info: user_audit_info)

              job.perform

              broker.reload
              expect(broker.name).to eq('test-broker')
              expect(broker.broker_url).to eq('http://example.org/new-broker-url')
              expect(broker.auth_username).to eq('username')
              expect(broker.auth_password).to eq('password')

              expect(updater_stub).to have_received(:refresh)
            end

            it 'updates the authentication and refreshes the catalog' do
              update_broker_request = ServiceBrokerUpdateRequest.create(
                authentication: '{"credentials":{"username":"new-admin","password":"welcome"}}',
                service_broker_id: broker.id
              )
              job = UpdateBrokerJob.new(update_broker_request.guid, broker.guid, previous_state, user_audit_info: user_audit_info)

              job.perform

              broker.reload
              expect(broker.name).to eq('test-broker')
              expect(broker.broker_url).to eq('http://example.org/broker-url')
              expect(broker.auth_username).to eq('new-admin')
              expect(broker.auth_password).to eq('welcome')

              expect(updater_stub).to have_received(:refresh)
            end
          end

          describe 'when there is a model level validation error' do
            before do
              allow_any_instance_of(ServiceBroker).to receive(:validate) do |record|
                # Make setting the state to 'AVAILABLE' fail, but nothing else
                if record.state == 'AVAILABLE'
                  record.errors.add(:something, 'is not right')
                end
              end
            end

            let(:previous_state) { ServiceBrokerStateEnum::DELETE_FAILED }

            it 'fails to update and raises InvalidServiceBroker' do
              expect {
                job.perform
              }.to raise_error(V3::ServiceBrokerUpdate::InvalidServiceBroker, 'something is not right')

              broker.reload
              expect(broker.state).to eq(ServiceBrokerStateEnum::DELETE_FAILED)
            end
          end

          context 'when catalog returned by broker is invalid' do
            before { setup_broker_with_invalid_catalog }

            it 'errors when there are validation errors' do
              job.perform
              fail('expected error to be raised')
            rescue ::CloudController::Errors::ApiError => e
              expect(e.message).to include(
                'Service broker catalog is invalid',
                  'Service dashboard_client id must be unique',
                  'Service service-name',
                  'nested-error'
              )
            end

            it 'rolls back any updates to the broker' do
              expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

              broker.reload

              expect(broker.name).to eq('test-broker')
              expect(broker.broker_url).to eq('http://example.org/broker-url')
              expect(broker.auth_username).to eq('username')
              expect(broker.auth_password).to eq('password')
              expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
            end

            it 'removes the service broker update request record' do
              expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)
              expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
            end
          end

          context 'when catalog returned by broker is incompatible' do
            before { incompatible_catalog }

            it 'errors when there are validation errors' do
              job.perform
              fail('expected error to be raised')
            rescue ::CloudController::Errors::ApiError => e
              expect(e.message).to include(
                'Service broker catalog is incompatible',
                  'Service 2 is declared to be a route service but support for route services is disabled.',
                  'Service 3 is declared to be a volume mount service but support for volume mount services is disabled.'
              )
            end

            it 'rolls back any updates to the broker' do
              expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

              broker.reload

              expect(broker.name).to eq('test-broker')
              expect(broker.broker_url).to eq('http://example.org/broker-url')
              expect(broker.auth_username).to eq('username')
              expect(broker.auth_password).to eq('password')
              expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
            end

            it 'removes the service broker update request record' do
              expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)
              expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
            end
          end

          context 'client manager' do
            context 'when catalog returned by broker causes UAA sync conflicts' do
              before do
                uaa_conflicting_catalog

                VCAP::CloudController::ServiceDashboardClient.make(
                  uaa_id: 'some-uaa-id'
                )
              end

              it 'errors when there are uaa synchronization errors' do
                job.perform
                fail('expected error to be raised')
              rescue ::CloudController::Errors::ApiError => e
                expect(e.message).to include(
                  'Service broker catalog is invalid',
                    'Service service_name',
                    'Service dashboard client id must be unique'
                )
              end

              it 'rolls back any updates to the broker' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

                broker.reload

                expect(broker.name).to eq('test-broker')
                expect(broker.broker_url).to eq('http://example.org/broker-url')
                expect(broker.auth_username).to eq('username')
                expect(broker.auth_password).to eq('password')
                expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
              end

              it 'removes the service broker update request record' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)
                expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
              end
            end

            context 'when it returns a warning' do
              let(:warning) { VCAP::Services::SSO::DashboardClientManager::REQUESTED_FEATURE_DISABLED_WARNING }

              before do
                allow_any_instance_of(VCAP::Services::SSO::DashboardClientManager).to receive(:has_warnings?).and_return(true)
                allow_any_instance_of(VCAP::Services::SSO::DashboardClientManager).to receive(:warnings).and_return([warning])
              end

              it 'then the warning gets stored' do
                job.perform

                expect(job.warnings).to include({ detail: warning })
              end
            end
          end

          context 'service manager' do
            context 'when service manager returns an error' do
              let(:service_manager) { instance_double(Services::ServiceBrokers::ServiceManager, sync_services_and_plans: nil) }
              let(:error) { StandardError.new('oh') }

              before do
                allow(Services::ServiceBrokers::ServiceManager).to receive(:new).and_return(service_manager)
                allow(service_manager).to receive(:sync_services_and_plans).and_raise(error)
              end

              it 'rolls back any updates to the broker' do
                expect { job.perform }.to raise_error(error)

                broker.reload

                expect(broker.name).to eq('test-broker')
                expect(broker.broker_url).to eq('http://example.org/broker-url')
                expect(broker.auth_username).to eq('username')
                expect(broker.auth_password).to eq('password')
                expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
              end

              it 'removes the service broker update request record' do
                expect { job.perform }.to raise_error(error)
                expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
              end
            end

            context 'when service manager returns a warning' do
              let(:service_manager) { instance_double(Services::ServiceBrokers::ServiceManager, sync_services_and_plans: nil) }
              let(:warning) { 'some catalog warning' }

              before do
                allow(Services::ServiceBrokers::ServiceManager).to receive(:new).and_return(service_manager)

                allow(service_manager).to receive(:has_warnings?).and_return(true)
                allow(service_manager).to receive(:warnings).and_return([warning])
              end

              it 'then the warning gets stored' do
                job.perform

                expect(job.warnings).to include({ detail: warning })
              end
            end
          end

          context 'when the update fails' do
            before do
              setup_broker_with_invalid_catalog
            end

            it 'rolls back the broker to its previous configuration' do
              expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

              broker.reload

              expect(broker.name).to eq('test-broker')
              expect(broker.broker_url).to eq('http://example.org/broker-url')
              expect(broker.auth_username).to eq('username')
              expect(broker.auth_password).to eq('password')
              expect(broker.state).to eq(ServiceBrokerStateEnum::AVAILABLE)

              expect(broker.labels.size).to eq(1)
              expect(broker.annotations.size).to eq(1)

              expect(broker.labels[0][:key_name]).to eq('potato')
              expect(broker.labels[0][:value]).to eq('yam')

              expect(broker.annotations[0][:key]).to eq('style')
              expect(broker.annotations[0][:value]).to eq('mashed')

              service_offerings = Service.where(service_broker_id: broker.id)
              expect(service_offerings.count).to eq(0)

              expect(ServiceBrokerUpdateRequest.where(id: update_broker_request.id).all).to be_empty
              expect(ServiceBrokerUpdateRequestLabelModel.where(id: update_broker_request.id).all).to be_empty
              expect(ServiceBrokerUpdateRequestAnnotationModel.where(id: update_broker_request.id).all).to be_empty
            end

            context 'and the broker was not available' do
              let(:previous_state) { ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED }

              it 'rolls back to the previous known state' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

                broker.reload
                expect(broker.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
              end
            end

            context 'and there is no previous state' do
              let(:previous_state) { '' }

              it 'rolls back to the previous known state' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

                broker.reload
                expect(broker.state).to be_empty
              end
            end
          end

          context 'when the broker ceases to exist during the job' do
            it 'raises a ServiceBrokerGone error' do
              broker.destroy

              expect { job.perform }.to raise_error(
                ::CloudController::Errors::V3::ApiError,
                  'The service broker was removed before the synchronization completed'
              )
            end
          end

          def setup_broker_with_invalid_catalog
            catalog = instance_double(Services::ServiceBrokers::V2::Catalog)

            allow(Services::ServiceBrokers::V2::Catalog).to receive(:new).
              and_return(catalog)

            validation_errors = Services::ValidationErrors.new
            validation_errors.add('Service dashboard_client id must be unique')

            validation_errors.add_nested(
              double('double-name', name: 'service-name'),
                Services::ValidationErrors.new.add('nested-error')
            )

            allow(catalog).to receive(:valid?).and_return(false)
            allow(catalog).to receive(:validation_errors).and_return(validation_errors)
          end

          def uaa_conflicting_catalog
            allow(Services::ServiceClientProvider).to receive(:provide).
              with(broker: broker).
              and_return(FakeServiceBrokerV2Client::WithConflictingUAAClient.new)
          end

          def incompatible_catalog
            catalog = instance_double(Services::ServiceBrokers::V2::Catalog)

            allow(Services::ServiceBrokers::V2::Catalog).to receive(:new).
              and_return(catalog)

            incompatibility_errors = Services::ValidationErrors.new
            incompatibility_errors.add('Service 2 is declared to be a route service but support for route services is disabled.')
            incompatibility_errors.add('Service 3 is declared to be a volume mount service but support for volume mount services is disabled.')

            allow(catalog).to receive(:valid?).and_return(true)
            allow(catalog).to receive(:compatible?).and_return(false)
            allow(catalog).to receive(:incompatibility_errors).and_return(incompatibility_errors)
          end
        end
      end
    end
  end
end
