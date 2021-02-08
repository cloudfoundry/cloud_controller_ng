require 'spec_helper'
require 'cloud_controller/user_audit_info'
require 'actions/v3/service_instance_update_managed'
require 'messages/service_instance_update_managed_message'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceInstanceUpdateManaged do
      subject(:action) { described_class.new(original_instance, message, user_audit_info, audit_hash) }
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
      let(:original_maintenance_info) { { version: '2.1.0', description: 'original version' } }
      let(:original_service_offering) { Service.make(plan_updateable: true) }
      let(:original_service_plan) { ServicePlan.make(service: original_service_offering, maintenance_info: original_maintenance_info) }
      let(:original_plan_guid) { original_service_plan.guid }
      let(:original_name) { 'si-test-name' }
      let(:new_name) { 'new-si-test-name' }
      let(:original_dashboard_url) { 'http://your-og-instance.com' }
      let!(:original_instance) do
        si = VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: original_service_plan,
          name: original_name,
          tags: %w(accounting mongodb),
          space: space,
          maintenance_info: original_maintenance_info,
          dashboard_url: original_dashboard_url
        )
        si.label_ids = [
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        ]
        si.annotation_ids = [
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
        ]
        si
      end
      let(:new_arbitrary_parameters) { { foo: 'bar' } }
      let(:message) { ServiceInstanceUpdateManagedMessage.new(body) }

      before do
        allow(Repositories::ServiceEventRepository).to receive(:new).and_return(event_repository)
      end

      describe '#preflight!' do
        describe 'invalid name updates' do
          context 'when the new name is already taken' do
            let(:instance_in_same_space) { ServiceInstance.make(space: original_instance.space) }
            let(:body) { { name: instance_in_same_space.name } }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceNameTaken')
              end
            end
          end

          context 'when changing the name of a shared service instance' do
            let(:shared_space) { Space.make }
            let(:body) { { name: 'funky-new-name' } }

            it 'raises' do
              original_instance.add_shared_space(shared_space)

              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('SharedServiceInstanceCannotBeRenamed')
              end
            end
          end
        end

        describe 'invalid plan updates' do
          let(:body) do
            {
              relationships: {
                service_plan: {
                  data: {
                    guid: new_service_plan.guid
                  }
                }
              }
            }
          end

          context 'when changing the plan and plan_updateable=false' do
            let(:original_service_plan) { ServicePlan.make(service: original_service_offering, plan_updateable: false) }
            let(:new_service_plan) { ServicePlan.make(service: original_service_offering) }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServicePlanNotUpdateable')
              end
            end
          end

          context 'when the space does not allow paid services' do
            before do
              quota = SpaceQuotaDefinition.make(
                non_basic_services_allowed: false,
                organization: org,
              )
              quota.add_space(space)
            end

            let(:original_service_plan) { ServicePlan.make(service: original_service_offering, free: true) }
            let(:new_service_plan) { ServicePlan.make(service: original_service_offering, free: false) }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
              end
            end
          end

          context 'when the org does not allow paid services' do
            before do
              quota = QuotaDefinition.make(non_basic_services_allowed: false)
              quota.add_organization(org)
            end

            let(:original_service_plan) { ServicePlan.make(service: original_service_offering, free: true) }
            let(:new_service_plan) { ServicePlan.make(service: original_service_offering, free: false) }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceServicePlanNotAllowed')
              end
            end
          end

          context 'when changing to a non-bindable plan' do
            let(:new_service_plan) { ServicePlan.make(service: original_service_offering, bindable: false) }

            before do
              ServiceBinding.make(
                app: AppModel.make(space: space),
                service_instance: original_instance
              )
            end

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServicePlanInvalid')
                expect(err.message).to eq('The service plan is invalid: cannot switch to non-bindable plan when service bindings exist')
              end
            end
          end
        end

        describe 'invalid maintenance_info updates' do
          let(:body) do
            {
              maintenance_info: {
                version: '3.1.1'
              }
            }
          end

          context 'when current plan does not support maintenance_info' do
            let(:original_service_plan) { ServicePlan.make(service: original_service_offering) }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('MaintenanceInfoNotSupported')
              end
            end
          end

          context 'when does not match the version in the plan' do
            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('MaintenanceInfoConflict')
              end
            end
          end

          context 'when changing plan and maintenance_info at the same time' do
            let(:body) do
              {
                maintenance_info: {
                  version: '4.2.1'
                },
                relationships: {
                  service_plan: {
                    data: {
                      guid: new_plan.guid
                    }
                  }
                }
              }
            end

            let(:new_plan) { ServicePlan.make(service: original_service_offering, maintenance_info: { version: '4.2.1' }) }

            it 'raises' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('MaintenanceInfoNotUpdatableWhenChangingPlan')
              end
            end
          end
        end

        describe 'when the plan is inactive' do
          let(:original_service_plan) { ServicePlan.make(service: original_service_offering, maintenance_info: original_maintenance_info, active: false) }

          context 'when updating parameters' do
            let(:body) { { parameters: { param1: 'value' } } }
            it 'raises error' do
              expect {
                action.preflight!
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('ServiceInstanceWithInaccessiblePlanNotUpdateable')
                expect(err.message).to eq('Cannot update parameters of a service instance that belongs to inaccessible plan')
              end
            end
          end

          context 'when updating maintenance_info' do
            context 'but it is not actually changing it' do
              let(:body) { { maintenance_info: original_maintenance_info } }

              it 'succeeds' do
                expect { action.preflight! }.not_to raise_error
              end
            end

            context 'and the maintenance_info is changing' do
              let(:body) { { maintenance_info: { version: '99.0.0' } } }

              it 'raises an error' do
                original_service_plan.update({ maintenance_info: { version: '99.0.0' } })
                expect {
                  action.preflight!
                }.to raise_error CloudController::Errors::ApiError do |err|
                  expect(err.name).to eq('ServiceInstanceWithInaccessiblePlanNotUpdateable')
                  expect(err.message).to eq('Cannot update maintenance_info of a service instance that belongs to inaccessible plan')
                end
              end
            end
          end

          context 'when updating name' do
            let(:body) { { name: 'new name' } }

            context 'when the offering allows context updates' do
              let(:original_service_offering) { Service.make(allow_context_updates: true) }

              it 'raises an error' do
                expect {
                  action.preflight!
                }.to raise_error CloudController::Errors::ApiError do |err|
                  expect(err.name).to eq('ServiceInstanceWithInaccessiblePlanNotUpdateable')
                  expect(err.message).to eq('Cannot update name of a service instance that belongs to inaccessible plan')
                end
              end
            end
          end
        end
      end

      describe '#try_update_sync' do
        describe 'no-op maintenance_info updates' do
          let(:body) do
            {
              maintenance_info: {
                version: original_maintenance_info[:version]
              }
            }
          end

          let(:original_service_plan) { ServicePlan.make(
            service: original_service_offering,
            maintenance_info: { version: '2.2.0', description: 'new version of plan' }
          )
          }

          it 'returns the current instance unchanged instance' do
            si, continue_async = action.try_update_sync

            expect(si).to eq(original_instance)
            expect(continue_async).to be_falsey
          end
        end

        describe 'database only updates' do
          context 'when only metadata is being updated' do
            let(:body) do
              {
                metadata: {
                  labels: {
                    foo: 'bar',
                    'pre.fix/to_delete': nil,
                  },
                  annotations: {
                    alpha: 'beta',
                    'pre.fix/to_delete': nil,
                  }
                }
              }
            end

            it 'updates the values in the service instance in the database' do
              action.try_update_sync

              original_instance.reload

              expect(original_instance).to have_annotations(
                { prefix: nil, key: 'alpha', value: 'beta' },
                { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
              )
              expect(original_instance).to have_labels(
                { prefix: nil, key: 'foo', value: 'bar' },
                { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
              )
            end

            it 'creates an audit event' do
              action.try_update_sync

              expect(event_repository).
                to have_received(:record_service_instance_event).with(
                  :update,
                  have_attributes(
                    name: original_name,
                    guid: original_instance.guid,
                    space: original_instance.space,
                  ),
                  body.with_indifferent_access
                )
            end
          end

          context 'change all fields that do not need broker operation' do
            let(:body) do
              {
                name: 'different-name',
                tags: %w(accounting couchbase nosql),
                maintenance_info: {
                  version: original_maintenance_info[:version]
                },
                metadata: {
                  labels: {
                    foo: 'bar',
                    'pre.fix/to_delete': nil,
                  },
                  annotations: {
                    alpha: 'beta',
                    'pre.fix/to_delete': nil,
                  }
                }
              }
            end

            it 'updates the values in the service instance in the database' do
              action.try_update_sync

              original_instance.reload

              expect(original_instance.name).to eq('different-name')
              expect(original_instance.tags).to eq(%w(accounting couchbase nosql))
              expect(original_instance).to have_annotations(
                { prefix: nil, key: 'alpha', value: 'beta' },
                { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
              )
              expect(original_instance).to have_labels(
                { prefix: nil, key: 'foo', value: 'bar' },
                { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
              )
            end

            it 'does not update the maintenance_info when it is unchanged' do
              action.try_update_sync
              original_instance.reload
              expect(original_instance.maintenance_info.symbolize_keys).to eq(original_maintenance_info)
            end

            it 'returns the updated service instance and no need to continue async' do
              si, continue_async = action.try_update_sync

              expect(si).to eq(original_instance.reload)
              expect(continue_async).to be_falsey
            end

            it 'sets last operation to update succeeded' do
              action.try_update_sync

              original_instance.reload

              expect(original_instance.last_operation.type).to eq('update')
              expect(original_instance.last_operation.state).to eq('succeeded')
            end

            it 'creates an audit event' do
              action.try_update_sync

              expect(event_repository).
                to have_received(:record_service_instance_event).with(
                  :update,
                  have_attributes(
                    name: original_name,
                    guid: original_instance.guid,
                    space: original_instance.space
                  ),
                  body.with_indifferent_access
                )
            end

            context 'when updating name' do
              context 'when the offering does not allow context updates' do
                let(:original_service_offering) { Service.make(allow_context_updates: false) }

                it 'succeeds' do
                  expect { action.try_update_sync }.not_to raise_error

                  original_instance.reload
                  expect(original_instance.name).to eq('different-name')
                end
              end
            end

            context 'SQL validation fails' do
              it 'raises an error and marks the update as failed' do
                errors = Sequel::Model::Errors.new
                errors.add(:blork, 'is busted')
                expect_any_instance_of(ManagedServiceInstance).to receive(:update).
                  and_raise(Sequel::ValidationFailed.new(errors))

                expect { action.try_update_sync }.
                  to raise_error(V3::ServiceInstanceUpdateManaged::InvalidServiceInstance, 'blork is busted')

                expect(original_instance.reload.last_operation.type).to eq('update')
                expect(original_instance.reload.last_operation.state).to eq('failed')
              end
            end
          end

          context 'when the update is empty' do
            let(:body) do
              {}
            end

            it 'succeeds' do
              si, continue_async = action.try_update_sync

              expect(si).to eq(original_instance.reload)
              expect(continue_async).to be_falsey
            end
          end

          context 'when the update requires communication with the broker' do
            let(:new_plan) { ServicePlan.make }
            let(:body) do
              {
                name: 'new-name',
                parameters: { foo: 'bar' },
                tags: %w(bar quz),
                relationships: {
                  service_plan: {
                    data: {
                      guid: new_plan.guid
                    }
                  }
                }
              }
            end

            describe 'fields that trigger broker interaction' do
              context 'parameters change requested' do
                let(:body) do
                  {
                    parameters: { foo: 'bar' },
                  }
                end

                it 'should return continue async' do
                  _, continue_async = action.try_update_sync

                  expect(continue_async).to be_truthy
                  original_instance.reload
                  expect(original_instance.last_operation.type).to eq('update')
                  expect(original_instance.last_operation.state).to eq('in progress')
                end
              end

              context 'plan change requested' do
                let(:body) do
                  {
                    relationships: {
                      service_plan: {
                        data: {
                          guid: new_plan.guid
                        }
                      }
                    }
                  }
                end

                it 'should return continue async' do
                  _, continue_async = action.try_update_sync

                  expect(continue_async).to be_truthy
                  original_instance.reload
                  expect(original_instance.last_operation.type).to eq('update')
                  expect(original_instance.last_operation.state).to eq('in progress')
                end
              end

              context 'name change requested' do
                let!(:original_service_plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
                let!(:original_instance) do
                  VCAP::CloudController::ManagedServiceInstance.make(
                    name: 'foo',
                    service_plan: original_service_plan
                  )
                end

                let(:body) do
                  {
                    name: 'new-different-name'
                  }
                end

                context 'context update is allowed in the broker' do
                  let!(:offering) do
                    VCAP::CloudController::Service.make(allow_context_updates: true)
                  end

                  it 'should return continue async' do
                    _, continue_async = action.try_update_sync

                    expect(continue_async).to be_truthy
                    original_instance.reload
                    expect(original_instance.last_operation.type).to eq('update')
                    expect(original_instance.last_operation.state).to eq('in progress')
                  end
                end

                context 'context update is not allowed in the broker' do
                  let!(:offering) do
                    VCAP::CloudController::Service.make(allow_context_updates: false)
                  end

                  it 'should return continue async false' do
                    _, continue_async = action.try_update_sync

                    expect(continue_async).to be_falsey
                  end
                end
              end

              context 'maintenance_info requested' do
                let(:original_service_plan) { ServicePlan.make(
                  service: original_service_offering,
                  maintenance_info: { version: '2.2.0', description: 'new version of plan' }
                )
                }

                let!(:original_instance) {
                  VCAP::CloudController::ManagedServiceInstance.make(
                    name: 'foo',
                    service_plan: original_service_plan,
                    maintenance_info: original_maintenance_info
                  )
                }

                let(:body) do
                  {
                    maintenance_info: { version: '2.2.0' },
                  }
                end

                it 'should return continue async' do
                  _, continue_async = action.try_update_sync

                  expect(continue_async).to be_truthy
                  original_instance.reload
                  expect(original_instance.last_operation.type).to eq('update')
                  expect(original_instance.last_operation.state).to eq('in progress')
                end

                context 'maintenance_info and other fields' do
                  let(:body) do
                    {
                      maintenance_info: { version: '2.2.0' },
                      name: 'something-different',
                      tags: ['a-new-tag'],
                      parameters: { new_param: 'bartender' },
                      relationships: {
                        service_plan: {
                          data: {
                            guid: original_instance.service_plan.guid
                          }
                        }
                      }
                    }
                  end

                  it 'should return continue async' do
                    _, continue_async = action.try_update_sync

                    expect(continue_async).to be_truthy
                    original_instance.reload
                    expect(original_instance.last_operation.type).to eq('update')
                    expect(original_instance.last_operation.state).to eq('in progress')
                  end
                end

                context 'changing parameters without maintenance_info when the plan was updated' do
                  let(:body) do
                    {
                      name: 'something-different',
                      tags: ['a-new-tag'],
                      parameters: { new_param: 'bartender' }

                    }
                  end

                  it 'should return continue async' do
                    _, continue_async = action.try_update_sync

                    expect(continue_async).to be_truthy
                    original_instance.reload
                    expect(original_instance.last_operation.type).to eq('update')
                    expect(original_instance.last_operation.state).to eq('in progress')
                  end
                end
              end
            end

            it 'does not update any attributes' do
              _, continue_async = action.try_update_sync

              expect(continue_async).to be_truthy

              original_instance.reload
              expect(original_instance.name).to eq(original_name)
              expect(original_instance.service_plan).to eq(original_service_plan)
              expect(original_instance.tags).to eq(%w(accounting mongodb))
            end

            it 'locks the service instance' do
              action.try_update_sync

              original_instance.reload
              expect(original_instance.last_operation.type).to eq('update')
              expect(original_instance.last_operation.state).to eq('in progress')
            end
          end
        end

        context 'when a delete is in progress' do
          let(:body) { {} }

          before do
            original_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
          end

          it 'raises' do
            expect {
              action.try_update_sync
            }.to raise_error CloudController::Errors::ApiError do |err|
              expect(err.name).to eq('AsyncServiceInstanceOperationInProgress')
            end
          end

          context 'with metadata only updates' do
            let(:body) { {
              metadata: {
                labels: {
                  foo: 'bar',
                  'pre.fix/to_delete': nil,
                },
                annotations: {
                  alpha: 'beta',
                  'pre.fix/to_delete': nil,
                }
              }
            }
            }
            it 'raises' do
              expect {
                action.try_update_sync
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('AsyncServiceInstanceOperationInProgress')
              end
            end
          end
        end

        context 'when an update is in progress' do
          before do
            original_instance.save_with_new_operation({}, { type: 'update', state: 'in progress' })
          end

          context 'metadata update' do
            let(:body) { {
              metadata: {
                labels: {
                  foo: 'bar',
                  'pre.fix/to_delete': nil,
                },
                annotations: {
                  alpha: 'beta',
                  'pre.fix/to_delete': nil,
                }
              }
            }
            }

            it 'allows metadata updates' do
              expect { action.try_update_sync }.not_to raise_error

              original_instance.reload

              expect(original_instance).to have_annotations(
                { prefix: nil, key: 'alpha', value: 'beta' },
                { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
              )
              expect(original_instance).to have_labels(
                { prefix: nil, key: 'foo', value: 'bar' },
                { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
              )
            end
          end

          context 'other updates' do
            let(:body) { { name: 'new-name' } }

            it 'raises' do
              expect {
                action.try_update_sync
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('AsyncServiceInstanceOperationInProgress')
              end
            end
          end
        end

        context 'when a create is in progress' do
          before do
            original_instance.save_with_new_operation({}, { type: 'create', state: 'in progress' })
          end

          context 'metadata update' do
            let(:body) { {
              metadata: {
                labels: {
                  foo: 'bar',
                  'pre.fix/to_delete': nil,
                },
                annotations: {
                  alpha: 'beta',
                  'pre.fix/to_delete': nil,
                }
              }
            }
            }

            it 'allows metadata updates' do
              expect { action.try_update_sync }.not_to raise_error

              original_instance.reload

              expect(original_instance).to have_annotations(
                { prefix: nil, key: 'alpha', value: 'beta' },
                { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
              )
              expect(original_instance).to have_labels(
                { prefix: nil, key: 'foo', value: 'bar' },
                { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
              )
            end
          end

          context 'other updates' do
            let(:body) { { name: 'new-name' } }

            it 'raises' do
              expect {
                action.try_update_sync
              }.to raise_error CloudController::Errors::ApiError do |err|
                expect(err.name).to eq('AsyncServiceInstanceOperationInProgress')
              end
            end
          end
        end
      end

      describe '#update' do
        let(:update_response) do
          {
            last_operation: {
              type: 'update',
              state: 'succeeded',
            }
          }
        end
        let(:client) do
          instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
            update: [update_response, nil],
          })
        end
        let(:new_plan) { ServicePlan.make }
        let(:new_name) { 'new-name' }
        let(:new_tags) { %w(bar quz) }
        let(:arbitrary_parameters) { { foo: 'bar' } }

        let(:body) do
          {
            name: new_name,
            parameters: arbitrary_parameters,
            tags: new_tags,
            relationships: {
              service_plan: {
                data: {
                  guid: new_plan.guid
                }
              }
            },
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                'seriouseats.com/potato': 'fried'
              }
            }
          }
        end
        let(:previous_values) {
          {
            plan_id: original_service_plan.broker_provided_id,
            service_id: original_service_offering.broker_provided_id,
            organization_id: org.guid,
            space_id: space.guid,
            maintenance_info: original_service_plan.maintenance_info.stringify_keys,
          }
        }

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'sends the operation request to the broker' do
          action.update(accepts_incomplete: true)

          expect(VCAP::Services::ServiceClientProvider).to have_received(:provide).with(instance: original_instance)
          expect(client).to have_received(:update).with(
            original_instance,
            new_plan,
            accepts_incomplete: true,
            arbitrary_parameters: { foo: 'bar' },
            maintenance_info: nil,
            name: new_name,
            previous_values: previous_values,
            user_guid: user_guid,
          )
        end

        context 'when update is sync' do
          let(:updated_dashboard_url) { 'http://your-instance.com' }
          let(:update_response) do
            {
              dashboard_url: updated_dashboard_url,
              last_operation: {
                type: 'update',
                state: 'succeeded',
              }
            }
          end

          it 'saves the updated instance' do
            action.update(accepts_incomplete: true)

            instance = original_instance.reload
            expect(instance).to_not be_nil
            expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
            expect(instance.name).to eq(new_name)
            expect(instance.tags).to eq(new_tags)
            expect(instance.service_plan).to eq(new_plan)
            expect(instance.space).to eq(space)
            expect(instance.dashboard_url).to eq(updated_dashboard_url)

            expect(instance.last_operation.type).to eq('update')
            expect(instance.last_operation.state).to eq('succeeded')

            expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
{ prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
            expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
{ prefix: nil, key: 'release', value: 'stable' })
          end

          it 'logs an audit event' do
            action.update(accepts_incomplete: true)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :update,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end

          describe 'individual property changes' do
            context 'when arbitrary parameters are changing' do
              let(:arbitrary_parameters) { { some_data: 'some_value' } }
              let(:body) do
                {
                  parameters: arbitrary_parameters
                }
              end

              it 'calls the broker client with the right arguments' do
                action.update(accepts_incomplete: true)

                expect(client).to have_received(:update).with(
                  original_instance,
                  original_service_plan,
                  accepts_incomplete: true,
                  arbitrary_parameters: arbitrary_parameters,
                  maintenance_info: nil,
                  name: original_name,
                  previous_values: previous_values,
                  user_guid: user_guid,
                )
              end

              it 'saves the updated instance' do
                action.update(accepts_incomplete: true)

                instance = original_instance.reload
                expect(instance).to_not be_nil
                expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
                expect(instance.name).to eq(original_name)
                expect(instance.service_plan).to eq(original_service_plan)
                expect(instance.space).to eq(space)
                expect(instance.dashboard_url).to eq(updated_dashboard_url)

                expect(instance.last_operation.type).to eq('update')
                expect(instance.last_operation.state).to eq('succeeded')

                expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' })
                expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' })
              end
            end

            context 'when name is changing' do
              let(:new_name) { 'new-name' }
              let(:body) do
                {
                  name: new_name
                }
              end

              it 'calls the broker client with the right arguments' do
                action.update(accepts_incomplete: true)

                expect(client).to have_received(:update).with(
                  original_instance,
                  original_service_plan,
                  accepts_incomplete: true,
                  arbitrary_parameters: {},
                  maintenance_info: nil,
                  name: new_name,
                  previous_values: previous_values,
                  user_guid: user_guid,
                )
              end

              it 'saves the updated instance' do
                action.update(accepts_incomplete: true)

                instance = original_instance.reload
                expect(instance).to_not be_nil
                expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
                expect(instance.name).to eq(new_name)
                expect(instance.service_plan).to eq(original_service_plan)
                expect(instance.space).to eq(space)
                expect(instance.dashboard_url).to eq(updated_dashboard_url)

                expect(instance.last_operation.type).to eq('update')
                expect(instance.last_operation.state).to eq('succeeded')

                expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' })
                expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' })
              end
            end

            context 'when service plan is changing' do
              let(:new_service_plan) { ServicePlan.make(
                service: original_service_offering,
                maintenance_info: { version: '2.2.0' },
                public: true
              )
              }
              let(:body) do
                {
                  relationships: {
                    service_plan: {
                      data: {
                        guid: new_service_plan.guid
                      }
                    }
                  }
                }
              end

              it 'calls the broker client with the right arguments' do
                action.update(accepts_incomplete: true)

                expect(client).to have_received(:update).with(
                  original_instance,
                  new_service_plan,
                  accepts_incomplete: true,
                  arbitrary_parameters: {},
                  maintenance_info: { version: '2.2.0' },
                  name: original_name,
                  previous_values: previous_values,
                  user_guid: user_guid,
                )
              end

              it 'saves the updated instance' do
                action.update(accepts_incomplete: true)

                instance = original_instance.reload
                expect(instance).to_not be_nil
                expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
                expect(instance.name).to eq(original_name)
                expect(instance.service_plan).to eq(new_service_plan)
                expect(instance.space).to eq(space)
                expect(instance.dashboard_url).to eq(updated_dashboard_url)
                expect(instance.maintenance_info).to eq(new_service_plan.maintenance_info)

                expect(instance.last_operation.type).to eq('update')
                expect(instance.last_operation.state).to eq('succeeded')

                expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' })
                expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' })
              end
            end

            context 'when maintenance info is changing' do
              let(:new_maintenance_info) { { version: '2.2.0' } }
              let(:body) do
                {
                  maintenance_info: new_maintenance_info
                }
              end

              it 'calls the broker client with the right arguments' do
                action.update(accepts_incomplete: true)

                expect(client).to have_received(:update).with(
                  original_instance,
                  original_service_plan,
                  accepts_incomplete: true,
                  arbitrary_parameters: {},
                  maintenance_info: { version: '2.2.0' },
                  name: original_name,
                  previous_values: previous_values,
                  user_guid: user_guid,
                )
              end

              it 'saves the updated instance' do
                action.update(accepts_incomplete: true)

                instance = original_instance.reload
                expect(instance).to_not be_nil
                expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
                expect(instance.name).to eq(original_name)
                expect(instance.service_plan).to eq(original_service_plan)
                expect(instance.space).to eq(space)
                expect(instance.dashboard_url).to eq(updated_dashboard_url)
                expect(instance.maintenance_info).to eq({ 'version' => '2.2.0' })

                expect(instance.last_operation.type).to eq('update')
                expect(instance.last_operation.state).to eq('succeeded')

                expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' })
                expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' })
              end
            end

            context 'when the service plan no longer exists' do
              let(:body) do
                {
                  relationships: { service_plan: { data: { guid: 'fake-plan' } } }
                }
              end

              it 'raises an error and records failure' do
                expect { action.update(accepts_incomplete: true)
                }.to raise_error(
                  ::CloudController::Errors::ApiError,
                  /The service plan could not be found/
                )

                instance = original_instance.reload
                expect(instance.last_operation.type).to eq('update')
                expect(instance.last_operation.state).to eq('failed')
                expect(instance.last_operation.description).to eq('The service plan could not be found: fake-plan')
              end
            end
          end

          context 'when update does not return dashboard_url' do
            let(:update_response) do
              {
                last_operation: {
                  type: 'update',
                  state: 'succeeded',
                }
              }
            end

            it 'saves the updated instance last operation' do
              action.update(accepts_incomplete: true)

              instance = original_instance.reload
              expect(instance).to_not be_nil
              expect(instance.dashboard_url).to eq(original_dashboard_url)

              expect(instance.last_operation.type).to eq('update')
              expect(instance.last_operation.state).to eq('succeeded')
            end
          end
        end

        context 'when update is async' do
          let(:broker_provided_operation) { Sham.guid }
          let(:updated_dashboard_url) { 'http://your-instance.com' }
          let(:update_response) do
            {
              dashboard_url: updated_dashboard_url,
              last_operation: {
                type: 'update',
                state: 'in progress',
                description: 'some description',
                broker_provided_operation: broker_provided_operation
              }
            }
          end

          it 'saves the updated instance last operation' do
            action.update(accepts_incomplete: true)

            instance = original_instance.reload
            expect(instance).to_not be_nil
            expect(instance).to eq(ServiceInstance.where(guid: instance.guid).first)
            expect(instance.name).to eq(original_name)
            expect(instance.service_plan).to eq(original_service_plan)
            expect(instance.space).to eq(space)
            expect(instance.dashboard_url).to eq(updated_dashboard_url)

            expect(instance.last_operation.type).to eq('update')
            expect(instance.last_operation.state).to eq('in progress')
            expect(instance.last_operation.broker_provided_operation).to eq(broker_provided_operation)
          end

          it 'logs a start update audit event' do
            action.update(accepts_incomplete: true)

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :start_update,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end

          context 'when update does not return dashboard_url' do
            let(:update_response) do
              {
                last_operation: {
                  type: 'update',
                  state: 'in progress',
                  description: 'some description',
                  broker_provided_operation: broker_provided_operation
                }
              }
            end

            it 'saves the updated instance last operation' do
              action.update(accepts_incomplete: true)

              instance = original_instance.reload
              expect(instance).to_not be_nil
              expect(instance.dashboard_url).to eq(original_dashboard_url)

              expect(instance.last_operation.type).to eq('update')
              expect(instance.last_operation.state).to eq('in progress')
              expect(instance.last_operation.broker_provided_operation).to eq(broker_provided_operation)
            end
          end
        end

        context 'when update raises an error' do
          before do
            allow(client).to receive(:update).and_return([{}, StandardError.new('boom')])
          end

          it 'raises an error and records failure' do
            expect { action.update(accepts_incomplete: true)
            }.to raise_error(
              StandardError,
              'boom'
            )

            instance = original_instance.reload
            expect(instance.last_operation.type).to eq('update')
            expect(instance.last_operation.state).to eq('failed')
            expect(instance.last_operation.description).to eq('boom')
          end
        end
      end

      describe '#poll' do
        let!(:original_instance) do
          si = VCAP::CloudController::ManagedServiceInstance.make(
            service_plan: original_service_plan,
            name: original_name,
            tags: %w(accounting mongodb),
            space: space,
            maintenance_info: original_maintenance_info,
            dashboard_url: original_dashboard_url
          )
          si.label_ids = [
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          ]
          si.annotation_ids = [
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
          ]
          si.save_with_new_operation(
            {},
            {
              type: 'update',
              state: 'in progress',
              broker_provided_operation: operation_id
            }
          )
          si
        end

        let(:operation_id) { Sham.guid }
        let(:poll_response) do
          {
            last_operation: {
              state: 'in progress'
            }
          }
        end
        let(:fetch_instance_response) { {} }
        let(:client) do
          instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
            fetch_service_instance_last_operation: poll_response,
            fetch_service_instance: fetch_instance_response
          })
        end

        let(:new_plan) { ServicePlan.make }
        let(:new_name) { 'new-name' }
        let(:new_tags) { %w(bar quz) }
        let(:arbitrary_parameters) { { foo: 'bar' } }
        let(:body) do
          {
            name: new_name,
            parameters: arbitrary_parameters,
            tags: new_tags,
            relationships: {
              service_plan: {
                data: {
                  guid: new_plan.guid
                }
              }
            },
            metadata: {
              labels: {
                release: 'stable'
              },
              annotations: {
                'seriouseats.com/potato': 'fried'
              }
            }
          }
        end
        let(:previous_values) {
          {
            plan_id: original_service_plan.broker_provided_id,
            service_id: original_service_offering.broker_provided_id,
            organization_id: org.guid,
            space_id: space.guid,
            maintenance_info: original_service_plan.maintenance_info.stringify_keys,
          }
        }

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'sends a poll to the client' do
          action.poll

          expect(client).to have_received(:fetch_service_instance_last_operation).with(
            original_instance,
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
            action.poll

            expect(ServiceInstance.first.last_operation.type).to eq('update')
            expect(ServiceInstance.first.last_operation.state).to eq('in progress')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation_id)
            expect(ServiceInstance.first.last_operation.description).to eq(description)
          end

          it 'returns the correct data' do
            result = action.poll

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

          it 'saves the updated instance' do
            action.poll

            instance = original_instance.reload
            expect(instance).to_not be_nil
            expect(instance.name).to eq(new_name)
            expect(instance.tags).to eq(new_tags)
            expect(instance.service_plan).to eq(new_plan)
            expect(instance.space).to eq(space)
            expect(instance.dashboard_url).to eq(original_dashboard_url)

            expect(instance.last_operation.type).to eq('update')
            expect(instance.last_operation.state).to eq('succeeded')

            expect(instance).to have_annotations({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
              { prefix: 'seriouseats.com', key: 'potato', value: 'fried' })
            expect(instance).to have_labels({ prefix: 'pre.fix', key: 'to_delete', value: 'value' }, { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
              { prefix: nil, key: 'release', value: 'stable' })
          end

          it 'updates an audit event' do
            action.poll

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :update,
              instance_of(ManagedServiceInstance),
              audit_hash
            )
          end

          it 'returns finished' do
            result = action.poll

            expect(result[:finished]).to be_truthy
          end

          context 'retrieving service instance' do
            context 'when service instance is not retrievable' do
              let(:service_offering) { Service.make(instances_retrievable: false) }
              let(:new_plan) { ServicePlan.make(service: service_offering) }

              it 'should not call fetch service instance' do
                action.poll

                expect(client).not_to have_received(:fetch_service_instance)
              end
            end

            context 'when service instance is retrievable' do
              let(:service) { Service.make(instances_retrievable: true) }
              let(:new_plan) { ServicePlan.make(service: service) }

              it 'should fetch service instance' do
                action.poll

                expect(client).to have_received(:fetch_service_instance).with(
                  original_instance,
                  user_guid: user_guid
                )
              end

              context 'when fetch returns dashboard_url' do
                let(:fetch_instance_response) do
                  {
                    dashboard_url: 'http://some-dashboard-url.com'
                  }
                end

                it 'updates the dashboard url' do
                  action.poll

                  instance = original_instance.reload
                  expect(instance).to_not be_nil
                  expect(instance.dashboard_url).to eq('http://some-dashboard-url.com')
                  expect(instance.last_operation.type).to eq('update')
                  expect(instance.last_operation.state).to eq('succeeded')
                end
              end

              context 'when fetch does not return dashboard_url' do
                let(:fetch_instance_response) do
                  {
                    parameters: { foo: 'bar' }
                  }
                end

                it 'does not update the dashboard url' do
                  action.poll

                  instance = original_instance.reload
                  expect(instance).to_not be_nil
                  expect(instance.dashboard_url).to eq(original_dashboard_url)
                  expect(instance.last_operation.type).to eq('update')
                  expect(instance.last_operation.state).to eq('succeeded')
                end
              end

              context 'when fetch raises' do
                before do
                  allow(client).to receive(:fetch_service_instance).and_raise(StandardError, 'boom')
                end

                it 'does not fair or update the dashboard url' do
                  action.poll

                  instance = original_instance.reload
                  expect(instance).to_not be_nil
                  expect(instance.dashboard_url).to eq(original_dashboard_url)
                  expect(instance.last_operation.type).to eq('update')
                  expect(instance.last_operation.state).to eq('succeeded')
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
              action.poll
            }.to raise_error(VCAP::CloudController::V3::ServiceInstanceUpdateManaged::LastOperationFailedState)

            expect(ServiceInstance.first.last_operation.type).to eq('update')
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
              action.poll
            }.to raise_error(
              StandardError,
              'boom'
            )

            expect(ServiceInstance.first.last_operation.type).to eq('update')
            expect(ServiceInstance.first.last_operation.state).to eq('failed')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to be_nil
            expect(ServiceInstance.first.last_operation.description).to eq('boom')
          end
        end
      end
    end
  end
end
