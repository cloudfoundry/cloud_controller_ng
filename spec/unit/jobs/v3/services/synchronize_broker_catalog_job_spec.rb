require 'rails_helper'
require 'jobs/v3/services/synchronize_broker_catalog_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe 'V3::SynchronizeServiceBrokerCatalogJob' do
        it_behaves_like 'delayed job', SynchronizeBrokerCatalogJob

        describe '#perform' do
          let(:broker) do
            ServiceBroker.create(
              name: 'test-broker',
              broker_url: 'http://example.org/broker-url',
              auth_username: 'username',
              auth_password: 'password'
            )
          end
          let(:service_manager_factory) { Services::ServiceBrokers::ServiceManager }
          let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: Sham.guid }) }

          subject(:job) do
            SynchronizeBrokerCatalogJob.new(broker.guid, user_audit_info: user_audit_info)
          end

          let(:broker_client) { FakeServiceBrokerV2Client.new }

          before do
            allow(Services::ServiceClientProvider).to receive(:provide).
              with(broker: broker).
              and_return(broker_client)
          end

          context 'when the broker has state' do
            before do
              broker.update(state: ServiceBrokerStateEnum::SYNCHRONIZING)
            end

            it 'creates the service offerings and plans from the catalog' do
              job.perform

              service_offerings = Service.where(service_broker_id: broker.id)
              expect(service_offerings.count).to eq(1)
              expect(service_offerings.first.label).to eq(broker_client.service_name)

              service_plans = ServicePlan.where(service_id: service_offerings.first.id)
              expect(service_plans.count).to eq(1)
              expect(service_plans.first.name).to eq(broker_client.plan_name)

              expect(broker.reload.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
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
            end

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
            end
          end

          context 'service broker created by legacy code that lacks any state' do
            it 'creates the state' do
              expect { job.perform }.to_not raise_error

              expect(broker.reload.state).to eq(ServiceBrokerStateEnum::AVAILABLE)
            end

            context 'when synchronization fails' do
              before { setup_broker_with_invalid_catalog }

              it 'also creates the state' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

                expect(broker.reload.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
              end
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

          context 'when the client manager returns a warning' do
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
