require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ServiceUpdateValidator, :services do
    describe '#validate_service_instance' do
      let(:service_broker_url) { "http://example.com/v2/service_instances/#{service_instance.guid}" }
      let(:service_broker) { ServiceBroker.make(broker_url: 'http://example.com', auth_username: 'auth_username', auth_password: 'auth_password') }
      let(:service) { Service.make(plan_updateable: true, service_broker: service_broker) }
      let(:old_service_plan) { ServicePlan.make(:v2, service: service, free: true, maintenance_info: { version: '2.0.0' }) }
      let(:new_service_plan) { ServicePlan.make(:v2, service: service) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }
      let(:space) { service_instance.space }

      let(:update_attrs) { {} }
      let(:args) do
        {
          space: space,
          service_plan: old_service_plan,
          service: service,
          update_attrs: update_attrs,
        }
      end

      context 'when the update to the service instance is valid' do
        it 'returns true' do
          expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
        end

        context 'and when plan update requested on a service that allows update' do
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          it 'returns true' do
            expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
          end
        end

        context 'and when maintenance_info update requested' do
          let(:update_attrs) { { 'maintenance_info' => { 'version' => '2.0.0' } } }

          it 'returns true' do
            expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
          end
        end

        context 'and when parameters update requested' do
          let(:update_attrs) { { 'parameters' => { 'foo' => 'bar' } } }
          let(:active) {}
          let(:public) {}

          let(:old_service_plan) { ServicePlan.make(:v2, service: service, active: active, public: public) }

          context 'when the current user is an admin' do
            before do
              set_current_user_as_admin
            end

            it 'always allows the update' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to be true
            end
          end

          context 'when the current user is space developer' do
            before do
              set_current_user_as_role(role: 'space_developer', space: space, org: space.organization)
            end

            context 'when the current plan is active and public' do
              let(:active) { true }
              let(:public) { true }

              it 'allows the update' do
                expect(ServiceUpdateValidator.validate!(service_instance, args)).to be true
              end
            end

            context 'when the current plan is active and visible only in the user org' do
              let(:active) { true }
              let(:public) { false }

              before do
                ServicePlanVisibility.make(organization: space.organization, service_plan: old_service_plan)
              end

              it 'allows the update' do
                expect(ServiceUpdateValidator.validate!(service_instance, args)).to be true
              end
            end
          end
        end
      end

      context 'when the update to the service instance is invalid' do
        context 'when the update changes the space' do
          let(:update_attrs) { { 'space_guid' => 'asdf' } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Cannot update space/)
          end
        end

        context 'when the model errors' do
          let(:smol_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'smol-space-quota-guid', organization: space.organization, total_services: 1) }

          before do
            ManagedServiceInstance.make(service_plan: old_service_plan, space: space)
            smol_space_quota.add_space(space)
          end
          let(:update_attrs) { { 'name' => 'new name' } }

          it 'raises a validation error with the specific message' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /You have exceeded your space's services limit./)
          end
        end

        context 'when the requested plan is not bindable' do
          let(:new_service_plan) { ServicePlan.make(:v2, service: service, bindable: false) }
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          context 'and service bindings exist' do
            before do
              ServiceBinding.make(
                app: AppModel.make(space: service_instance.space),
                service_instance: service_instance
              )
            end

            it 'raises a validation error' do
              expect {
                ServiceUpdateValidator.validate!(service_instance, args)
              }.to raise_error(CloudController::Errors::ApiError, /cannot switch to non-bindable/)
            end
          end

          context 'and service bindings do not exist' do
            it 'returns true' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'when the service does not allow plan updates' do
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          before do
            service.plan_updateable = false
          end

          it 'raises a validation error if the plan changes' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /service does not support changing plans/)
          end

          context 'when the plan does not change' do
            let(:update_attrs) { { 'service_plan_guid' => old_service_plan.guid } }

            it 'returns true' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end

          context 'when the plan has plan_updateable set to true' do
            before do
              old_service_plan.plan_updateable = true
            end

            it 'returns true' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end

          context 'when the plan has plan_updateable set to false' do
            before do
              old_service_plan.plan_updateable = false
            end

            it 'raises a validation error' do
              expect {
                ServiceUpdateValidator.validate!(service_instance, args)
              }.to raise_error(CloudController::Errors::ApiError, /service does not support changing plans/)
            end
          end
        end

        context 'when the service allows updates but plan does not' do
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          before do
            old_service_plan.plan_updateable = false
          end

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /service does not support changing plans/)
          end
        end

        context 'when the plan does not exist' do
          let(:update_attrs) { { 'service_plan_guid' => 'does-not-exist' } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Plan/)
          end
        end

        context 'when the plan is in a different service' do
          let(:other_broker) { ServiceBroker.make }
          let(:other_service) { Service.make(plan_updateable: true, service_broker: other_broker) }
          let(:new_service_plan) { ServicePlan.make(:v2, service: other_service) }
          let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          it 'raises a validation error' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(CloudController::Errors::ApiError, /Plan/)
          end
        end

        context 'when the service instance is shared' do
          let(:shared_space) { Space.make }

          before do
            service_instance.add_shared_space(shared_space)
          end

          context 'when the name is changed' do
            let(:update_attrs) { { 'name' => 'something_new' } }

            it 'raises a validation error' do
              expect {
                ServiceUpdateValidator.validate!(service_instance, args)
              }.to raise_error(CloudController::Errors::ApiError, /shared cannot be renamed/)
            end
          end

          context 'when the name is not changed' do
            let(:update_attrs) { { 'name' => service_instance.name } }

            it 'succeeds' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'when mismatching maintenance_info update requested' do
          let(:update_attrs) { { 'maintenance_info' => { 'version' => '1.0.0' } } }

          it 'succeeds' do
            expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
          end
        end

        context 'when maintenance_info is absent on service_plan and maintenance_info update requested' do
          let(:update_attrs) { { 'maintenance_info' => { 'version' => '2.0.0' } } }
          let(:old_service_plan) { ServicePlan.make(:v2, service: service, free: true) }

          it 'errors' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(
              CloudController::Errors::ApiError,
              'The service broker does not support upgrades for service instances created from this plan.'
            )
          end
        end

        context 'when maintenance_info.version is not valid semantic version' do
          let(:update_attrs) { { 'maintenance_info' => { 'version' => 'not a semantic version' } } }

          it 'errors' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(
              CloudController::Errors::ApiError,
              'maintenance_info.version should be a semantic version.'
            )
          end
        end

        context 'when maintenance_info and plan_id are changed' do
          let(:update_attrs) { {
            'maintenance_info' => { 'version' => '2.0.0' },
            'service_plan_guid' => new_service_plan.guid }
          }

          it 'errors' do
            expect {
              ServiceUpdateValidator.validate!(service_instance, args)
            }.to raise_error(
              CloudController::Errors::ApiError,
              'maintenance_info should not be changed when switching to different plan.'
            )
          end
        end

        context 'paid plans' do
          let(:old_service_plan) { ServicePlan.make(:v2, service: service, free: false) }

          let(:free_quota) do
            QuotaDefinition.make(
              total_services: 10,
              non_basic_services_allowed: false
            )
          end

          let(:free_plan) { ServicePlan.make(:v2, free: true) }
          let(:org) { Organization.make(quota_definition: free_quota) }
          let(:developer) { make_developer_for_space(space) }

          context 'when paid plans are disabled for the quota' do
            let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }

            before do
              space.space_quota_definition = free_quota
              space.space_quota_definition.save
            end

            context 'when changing the instance parameters' do
              let(:update_attrs) { { 'toppings' => 'anchovies' } }

              it 'errors' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /paid service plans are not allowed/)
              end
            end

            context 'when changing to an unpaid plan from a paid plan' do
              let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: true) }
              let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

              it 'succeeds' do
                expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
              end

              it 'does not update the plan on the service instance' do
                ServiceUpdateValidator.validate!(service_instance, args)
                expect(service_instance.service_plan).to eq(old_service_plan)
                expect(service_instance.reload.service_plan).to eq(old_service_plan)
              end
            end

            context 'when changing to a different paid plan from a paid plan' do
              let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: false) }
              let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

              it 'errors' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /paid service plans are not allowed/)
              end

              it 'does not update the plan on the service instance' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError)

                expect(service_instance.service_plan).to eq(old_service_plan)
                expect(service_instance.reload.service_plan).to eq(old_service_plan)
              end
            end
          end

          context 'when paid plans are enabled for the quota' do
            let(:new_service_plan) { ServicePlan.make(:v2, service: service, free: false) }
            let(:update_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

            it 'succeeds for paid plans' do
              expect(ServiceUpdateValidator.validate!(service_instance, args)).to eq(true)
            end
          end
        end

        context 'when parameters update requested' do
          let(:update_attrs) { { 'parameters' => { 'foo' => 'bar' } } }

          let(:old_service_plan) { ServicePlan.make(:v2, service: service, active: active, public: public) }

          let(:active) {}
          let(:public) {}

          context 'when the current user is space developer' do
            before do
              set_current_user_as_role(role: 'space_developer', space: space, org: space.organization)
            end

            context 'when the current plan is not active and not public' do
              let(:active) { false }
              let(:public) { false }

              it 'raises a validation error' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /Cannot update parameters of a service instance that belongs to inaccessible plan/)
              end
            end

            context 'when the current plan is active but not visible to the user' do
              let(:active) { true }
              let(:public) { false }

              it 'raises a validation error' do
                expect {
                  ServiceUpdateValidator.validate!(service_instance, args)
                }.to raise_error(CloudController::Errors::ApiError, /Cannot update parameters of a service instance that belongs to inaccessible plan/)
              end
            end
          end
        end
      end
    end
  end
end
