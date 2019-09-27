require 'rails_helper'
require 'jobs/v3/synchronize_broker_catalog_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe 'V3::SynchronizeServiceBrokerCatalogJob' do
        describe '#perform' do
          let(:broker) do
            ServiceBroker.create(
              name: 'test-broker',
              broker_url: 'http://example.org/broker-url',
              auth_username: 'username',
              auth_password: 'password'
            )
          end

          subject(:job) { SynchronizeBrokerCatalogJob.new(broker.guid) }

          let(:broker_client) { FakeServiceBrokerV2Client.new }
          let(:broker_state) { ServiceBrokerState.where(service_broker_id: broker.id).first.state }

          before do
            allow(Services::ServiceClientProvider).to receive(:provide).
              with(broker: broker).
              and_return(broker_client)
          end

          context 'when the broker has state' do
            before do
              broker.update(
                service_broker_state: ServiceBrokerState.new(
                  state: ServiceBrokerStateEnum::SYNCHRONIZING
                )
              )
            end

            it 'creates the service offerings and plans from the catalog' do
              job.perform

              service_offerings = Service.where(service_broker_id: broker.id)
              expect(service_offerings.count).to eq(1)
              expect(service_offerings.first.label).to eq(broker_client.service_name)

              service_plans = ServicePlan.where(service_id: service_offerings.first.id)
              expect(service_plans.count).to eq(1)
              expect(service_plans.first.name).to eq(broker_client.plan_name)

              expect(broker_state).to eq(ServiceBrokerStateEnum::AVAILABLE)
            end

            context 'when catalog returned by broker is invalid' do
              before { invalid_catalog }

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
          end

          context 'service broker created by legacy code that lacks any state' do
            it 'creates the state' do
              expect { job.perform }.to_not raise_error

              expect(broker_state).to eq(ServiceBrokerStateEnum::AVAILABLE)
            end

            context 'when synchronization fails' do
              before { invalid_catalog }

              it 'also creates the state' do
                expect { job.perform }.to raise_error(::CloudController::Errors::ApiError)

                expect(broker_state).to eq(ServiceBrokerStateEnum::SYNCHRONIZATION_FAILED)
              end
            end
          end
        end

        def invalid_catalog
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
