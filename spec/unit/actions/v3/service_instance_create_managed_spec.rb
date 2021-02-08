require 'spec_helper'
require 'cloud_controller/user_audit_info'
require 'actions/v3/service_instance_create_managed'
require 'messages/service_instance_create_managed_message'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceInstanceCreateManaged do
      subject(:action) { described_class.new(user_audit_info, audit_hash) }
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: user_guid, user_email: 'example@email.com', user_name: 'best_user' }) }
      let(:audit_hash) { { woo: 'baz' } }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository)
        allow(dbl).to receive(:record_service_instance_event)
        allow(dbl).to receive(:user_audit_info).and_return(user_audit_info)
        dbl
      end

      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:space_guid) { space.guid }
      let(:maintenance_info) do
        {
          'version' => '0.1.2',
          'description' => 'amazing plan'
        }
      end
      let(:service_plan) { ServicePlan.make(maintenance_info: maintenance_info) }
      let(:plan_guid) { service_plan.guid }
      let(:name) { 'si-test-name' }
      let(:arbitrary_parameters) { { foo: 'bar' } }
      let(:message) {
        VCAP::CloudController::ServiceInstanceCreateManagedMessage.new(
          {
            type: 'managed',
            name: name,
            parameters: arbitrary_parameters,
            relationships: {
              service_plan: {
                data: { guid: plan_guid }
              },
              space: {
                data: { guid: space_guid }
              }
            },
            tags: %w(accounting mongodb),
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                'seriouseats.com/potato': 'fried'
              }
            }
          }
        )
      }

      before do
        allow(Repositories::ServiceEventRepository).to receive(:new).and_return(event_repository)
      end

      describe '#precursor' do
        it 'returns a service instance precursor' do
          instance = action.precursor(message: message)

          expect(instance).to_not be_nil
          expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
          expect(instance.name).to eq(name)
          expect(instance.tags).to eq(%w(accounting mongodb))
          expect(instance.service_plan).to eq(service_plan)
          expect(instance.space).to eq(space)
          expect(instance.maintenance_info).to eq(maintenance_info)

          expect(instance.last_operation.type).to eq('create')
          expect(instance.last_operation.state).to eq('in progress')

          expect(instance).to have_annotations({ prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
          expect(instance).to have_labels({ prefix: nil, key: 'release', value: 'stable' })
        end

        describe 'service plan does not exist' do
          let(:plan_guid) { Sham.guid }

          it 'should raise' do
            expect { action.precursor(message: message) }.to raise_error(
              ServiceInstanceCreateManaged::InvalidManagedServiceInstance,
              'Service plan not found.'
            )
          end
        end

        describe 'broker is unavaliable' do
          let(:broker) { ServiceBroker.make(state: ServiceBrokerStateEnum::SYNCHRONIZING) }
          let(:offering) { Service.make(service_broker: broker) }
          let(:service_plan) { ServicePlan.make(service: offering, maintenance_info: maintenance_info) }

          it 'should raise' do
            expect { action.precursor(message: message) }.to raise_error(
              CloudController::Errors::ApiError,
              'The service instance cannot be created because there is an operation in progress for the service broker.'
            )
          end
        end

        describe 'name already in use' do
          before do
            ManagedServiceInstance.make(name: name, space: space)
          end

          it 'should raise' do
            expect { action.precursor(message: message) }.to raise_error(
              ServiceInstanceCreateManaged::InvalidManagedServiceInstance,
              'The service instance name is taken: si-test-name.'
            )
          end
        end

        context 'SQL validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect_any_instance_of(ManagedServiceInstance).to receive(:save_with_new_operation).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect { action.precursor(message: message) }.
              to raise_error(ServiceInstanceCreateManaged::InvalidManagedServiceInstance, 'blork is busted')
          end
        end

        context 'quotas' do
          context 'when service instance limit has been reached for the space' do
            before do
              quota = SpaceQuotaDefinition.make(total_services: 1, organization: org)
              quota.add_space(space)
              ManagedServiceInstance.make(space: space)
            end

            it 'raises' do
              expect {
                action.precursor(message: message)
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceSpaceQuotaExceeded')
              end
            end
          end

          context 'when service instance limit has been reached for the org' do
            before do
              quotas = QuotaDefinition.make(total_services: 1)
              quotas.add_organization(org)
              ManagedServiceInstance.make(space: space)
            end

            it 'raises' do
              expect {
                action.precursor(message: message)
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceQuotaExceeded')
              end
            end
          end

          context 'when the space does not allow paid services' do
            let(:service_plan) { ServicePlan.make(public: true, free: false, active: true) }

            before do
              quota = SpaceQuotaDefinition.make(non_basic_services_allowed: false, organization: org)
              quota.add_space(space)
            end

            it 'raises' do
              expect {
                action.precursor(message: message)
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
              end
            end
          end

          context 'when the org does not allow paid services' do
            let(:service_plan) { ServicePlan.make(free: false, public: true, active: true) }

            before do
              quota = QuotaDefinition.make(non_basic_services_allowed: false)
              quota.add_organization(org)
            end

            it 'raises' do
              expect {
                action.precursor(message: message)
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceServicePlanNotAllowed')
              end
            end
          end
        end
      end

      describe '#provision' do
        let(:provision_response) do
          {
            instance: {

            },
            last_operation: {
              state: 'succeeded',
            }
          }
        end
        let(:client) do
          instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
            provision: provision_response,
          })
        end
        let(:precursor) { action.precursor(message: message) }

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'sends a provision request to the client' do
          action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)

          expect(VCAP::Services::ServiceClientProvider).to have_received(:provide).with(instance: precursor)
          expect(client).to have_received(:provision).with(
            precursor,
            arbitrary_parameters: arbitrary_parameters,
            accepts_incomplete: true,
            maintenance_info: maintenance_info,
            user_guid: user_guid
          )
        end

        context 'when provision is sync' do
          let(:provision_response) do
            {
              instance: {
                dashboard_url: 'http://your-instance.com'
              },
              last_operation: {
                type: 'create',
                state: 'succeeded',
              }
            }
          end

          it 'saves the completed instance' do
            action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)

            instance = precursor.reload
            expect(instance).to_not be_nil
            expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
            expect(instance.name).to eq(name)
            expect(instance.tags).to eq(%w(accounting mongodb))
            expect(instance.service_plan).to eq(service_plan)
            expect(instance.space).to eq(space)
            expect(instance.maintenance_info).to eq(maintenance_info)
            expect(instance.dashboard_url).to eq('http://your-instance.com')

            expect(instance.last_operation.type).to eq('create')
            expect(instance.last_operation.state).to eq('succeeded')

            expect(instance).to have_annotations({ prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
            expect(instance).to have_labels({ prefix: nil, key: 'release', value: 'stable' })
          end

          it 'logs an audit event' do
            action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :create,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end
        end

        context 'when provision is async' do
          let(:broker_provided_operation) { Sham.guid }
          let(:provision_response) do
            {
              instance: {},
              last_operation: {
                type: 'create',
                state: 'in progress',
                description: 'some description',
                broker_provided_operation: broker_provided_operation
              }
            }
          end

          it 'saves the updated instance last operation' do
            action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)

            instance = precursor.reload
            expect(instance).to_not be_nil
            expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
            expect(instance.name).to eq(name)
            expect(instance.tags).to eq(%w(accounting mongodb))
            expect(instance.service_plan).to eq(service_plan)
            expect(instance.space).to eq(space)
            expect(instance.maintenance_info).to eq(maintenance_info)
            expect(instance.dashboard_url).to be_nil

            expect(instance.last_operation.type).to eq('create')
            expect(instance.last_operation.state).to eq('in progress')
            expect(instance.last_operation.broker_provided_operation).to eq(broker_provided_operation)

            expect(instance).to have_annotations({ prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
            expect(instance).to have_labels({ prefix: nil, key: 'release', value: 'stable' })
          end

          it 'logs a start create audit event' do
            action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :start_create,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end
        end

        context 'when provision raises an error' do
          before do
            allow(client).to receive(:provision).and_raise StandardError.new('boom')
          end

          it 'raises an error and records failure' do
            expect { action.provision(precursor, parameters: arbitrary_parameters, accepts_incomplete: true)
            }.to raise_error(
              StandardError,
              'boom'
            )

            instance = precursor.reload
            expect(instance.last_operation.type).to eq('create')
            expect(instance.last_operation.state).to eq('failed')
            expect(instance.last_operation.description).to eq('boom')
          end
        end
      end

      describe '#poll' do
        let(:provision_dashboard_url) { 'http://your-instance.com' }
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make.tap do |i|
            i.save_with_new_operation(
              {
                service_plan: service_plan,
                dashboard_url: 'http://your-instance.com'
              },
              {
                type: 'create',
                state: 'in progress',
                broker_provided_operation: operation_id
              }
            )
          end
        end

        let(:operation_id) { Sham.guid }
        let(:poll_response) do
          {
            last_operation: {
              state: 'in progress'
            }
          }
        end
        let(:fetch_instance_response) do {}
        end
        let(:client) do
          instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
            fetch_service_instance_last_operation: poll_response,
            fetch_service_instance: fetch_instance_response
          })
        end

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'sends a poll to the client' do
          action.poll(service_instance)

          expect(client).to have_received(:fetch_service_instance_last_operation).with(
            service_instance,
            user_guid: user_guid
          )
        end

        context 'when the operation is still in progress' do
          let(:description) { Sham.description }
          let(:retry_after) { 42 }
          let(:poll_response) do
            {
              last_operation: {
                state: 'in progress',
                description: description
              },
              retry_after: retry_after
            }
          end

          it 'updates the last operation description' do
            action.poll(service_instance)

            expect(ServiceInstance.first.last_operation.type).to eq('create')
            expect(ServiceInstance.first.last_operation.state).to eq('in progress')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation_id)
            expect(ServiceInstance.first.last_operation.description).to eq(description)
          end

          it 'returns the correct data' do
            result = action.poll(service_instance)

            expect(result[:finished]).to be_falsey
            expect(result[:retry_after]).to eq(retry_after)
          end
        end

        context 'when the has finished successfully' do
          let(:description) { Sham.description }
          let(:poll_response) do
            {
              last_operation: {
                state: 'succeeded',
                description: description
              },
            }
          end

          it 'updates last operation' do
            action.poll(service_instance)

            service_instance.reload
            expect(service_instance).to_not be_nil
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('succeeded')
          end

          it 'creates an audit event' do
            action.poll(service_instance)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :create,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end

          it 'returns finished' do
            result = action.poll(service_instance)

            expect(result[:finished]).to be_truthy
          end

          context 'retrieving service instance' do
            context 'when service instance is not retrievable' do
              let(:service_offering) { Service.make(instances_retrievable: false) }
              let(:service_plan) { ServicePlan.make(service: service_offering) }

              it 'should not call fetch service instance' do
                action.poll(service_instance)

                expect(client).not_to have_received(:fetch_service_instance)
              end
            end

            context 'when service instance is retrievable' do
              let(:service) { Service.make(instances_retrievable: true) }
              let(:service_plan) { ServicePlan.make(service: service) }

              it 'should fetch service instance' do
                action.poll(service_instance)

                expect(client).to have_received(:fetch_service_instance).with(
                  service_instance,
                  user_guid: user_guid
                )
              end

              context 'when fetch returns dashboard_url' do
                let(:fetch_dashboard_url) { 'http://some-dashboard-url.com' }

                let(:fetch_instance_response) do
                  {
                    dashboard_url: fetch_dashboard_url
                  }
                end

                it 'updates the dashboard url' do
                  action.poll(service_instance)

                  service_instance.reload
                  expect(service_instance).to_not be_nil
                  expect(service_instance.dashboard_url).to eq(fetch_dashboard_url)
                  expect(service_instance.last_operation.type).to eq('create')
                  expect(service_instance.last_operation.state).to eq('succeeded')
                end
              end

              context 'when fetch does not return dashboard_url' do
                let(:fetch_instance_response) do
                  {
                    parameters: { foo: 'bar' }
                  }
                end

                it 'does not update the dashboard url' do
                  action.poll(service_instance)

                  service_instance.reload
                  expect(service_instance).to_not be_nil
                  expect(service_instance.dashboard_url).to eq(provision_dashboard_url)
                  expect(service_instance.last_operation.type).to eq('create')
                  expect(service_instance.last_operation.state).to eq('succeeded')
                end
              end

              context 'when fetch raises' do
                before do
                  allow(client).to receive(:fetch_service_instance).and_raise(StandardError, 'boom')
                end

                it 'does not fair or update the dashboard url' do
                  action.poll(service_instance)

                  service_instance.reload
                  expect(service_instance).to_not be_nil
                  expect(service_instance.dashboard_url).to eq(provision_dashboard_url)
                  expect(service_instance.last_operation.type).to eq('create')
                  expect(service_instance.last_operation.state).to eq('succeeded')
                end
              end
            end
          end
        end

        context 'when the operation has failed' do
          let(:description) { Sham.description }
          let(:poll_response) do
            {
              last_operation: {
                state: 'failed',
                description: description
              },
            }
          end

          it 'raises and updates the last operation description' do
            expect {
              action.poll(service_instance)
            }.to raise_error(VCAP::CloudController::V3::ServiceInstanceCreateManaged::LastOperationFailedState)

            expect(ServiceInstance.first.last_operation.type).to eq('create')
            expect(ServiceInstance.first.last_operation.state).to eq('failed')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation_id)
            expect(ServiceInstance.first.last_operation.description).to eq(description)
          end
        end

        context 'when the client raises' do
          before do
            allow(client).to receive(:fetch_service_instance_last_operation).and_raise(StandardError, 'boom')
          end

          it 'updates the last operation description' do
            expect {
              action.poll(service_instance)
            }.to raise_error(
              StandardError,
              'boom'
            )

            expect(ServiceInstance.first.last_operation.type).to eq('create')
            expect(ServiceInstance.first.last_operation.state).to eq('failed')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to be_nil
            expect(ServiceInstance.first.last_operation.description).to eq('boom')
          end
        end
      end
    end
  end
end
