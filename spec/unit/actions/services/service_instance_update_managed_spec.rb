require 'spec_helper'
require 'actions/services/service_instance_update'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdate do
    let(:services_event_repo) do
      instance_double(Repositories::ServiceEventRepository, record_service_instance_event: nil, user_audit_info: user_audit_info)
    end
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:service_instance_update) do
      ServiceInstanceUpdate.new(
        accepts_incomplete: false,
        services_event_repository: services_event_repo
      )
    end
    let(:service_broker) { ServiceBroker.make }
    let(:allow_context_updates) { false }
    let(:service) { Service.make(plan_updateable: true, service_broker: service_broker, allow_context_updates: allow_context_updates) }
    let(:old_service_plan) { ServicePlan.make(:v2, service: service) }
    let(:new_plan_maintenance_info) {}
    let(:new_service_plan) { ServicePlan.make(:v2, service: service, maintenance_info: new_plan_maintenance_info) }
    let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan,
                                                         maintenance_info: old_service_plan.maintenance_info,
                                                         tags: [],
                                                         name: 'Old name')
    }

    let(:updated_name) { 'New name' }
    let(:updated_parameters) { { 'thing1' => 'thing2' } }
    let(:updated_tags) { ['tag1', 'tag2'] }
    let(:request_attrs) {
      {
        'parameters' => updated_parameters,
        'name' => updated_name,
        'tags' => updated_tags,
        'service_plan_guid' => new_service_plan.guid,
        'maintenance_info' => { 'version' => '1.4.5a' },
      }
    }

    describe 'updating multiple attributes' do
      before do
        stub_update service_instance
      end

      it 'can update all the attributes at the same time' do
        service_instance_update.update_service_instance(service_instance, request_attrs)

        service_instance.reload

        expect(service_instance.name).to eq(updated_name)
        expect(service_instance.tags).to eq(updated_tags)
        expect(service_instance.service_plan.guid).to eq(new_service_plan.guid)
        expect(service_instance.maintenance_info).to eq(new_service_plan.maintenance_info)

        expect(
          a_request(:patch, update_url(service_instance)).with do |req|
            expect(JSON.parse(req.body)).to include({
              'parameters' => updated_parameters,
              'plan_id' => new_service_plan.broker_provided_id,
              'previous_values' => {
                'plan_id' => old_service_plan.broker_provided_id,
                'service_id' => service_instance.service.broker_provided_id,
                'organization_id' => service_instance.organization.guid,
                'space_id' => service_instance.space.guid,
              }
            })
          end
        ).to have_been_made.once
      end

      describe 'failure cases' do
        context 'when the update times out' do
          before do
            stub_update(service_instance, body: lambda { |r|
              sleep 10
              raise 'Should time out'
            })
          end

          it 'should mark the service instance as failed' do
            expect {
              Timeout.timeout(0.5.second) do
                service_instance_update.update_service_instance(service_instance, { 'parameters' => { 'foo' => 'bar' } })
              end
            }.to raise_error(Timeout::Error)

            service_instance.reload

            expect(a_request(:patch, update_url(service_instance))).
              to have_been_made.times(1)
            expect(service_instance.last_operation.type).to eq('update')
            expect(service_instance.last_operation.state).to eq('failed')
          end
        end

        context 'when there is a validation failure' do
          it 'unlocks the service instance' do
            tags = ['a'] * 2049
            expect {
              service_instance_update.update_service_instance(service_instance, { 'tags' => tags })
            }.to raise_error(Sequel::ValidationFailed, /too_long/)
            expect(service_instance.last_operation.state).to eq('failed')
          end
        end

        context 'when the broker returns an error' do
          before do
            stub_update(service_instance, status: 500)
          end

          it 'rolls back other changes' do
            old_name = service_instance.name

            expect {
              service_instance_update.update_service_instance(service_instance, request_attrs)
            }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)

            service_instance.reload
            expect(service_instance.name).to eq(old_name)
            expect(service_instance.service_plan.guid).to eq(old_service_plan.guid)
            expect(service_instance.tags).to be_empty
          end

          context 'when an updated field fails validations' do
            let(:request_attrs) {
              {
                'name' => 'name' * 1000,
                'tags' => ['new', 'tags'],
                'service_plan_guid' => new_service_plan.guid
              }
            }

            it 'rolls back changes' do
              old_tags = service_instance.tags
              old_name = service_instance.name

              expect {
                service_instance_update.update_service_instance(service_instance, request_attrs)
              }.to raise_error(Sequel::ValidationFailed, /max_length/)

              service_instance.reload
              expect(service_instance.name).to eq(old_name)
              expect(service_instance.tags).to eq(old_tags)
              expect(service_instance.service_plan.guid).to eq(old_service_plan.guid)
            end

            it 'does not update the broker' do
              expect {
                service_instance_update.update_service_instance(service_instance, request_attrs)
              }.to raise_error(Sequel::ValidationFailed, /max_length/)

              expect(
                a_request(:patch, update_url(service_instance)).with(
                  body: hash_including({
                    'plan_id' => new_service_plan.broker_provided_id
                  })
                )
              ).not_to have_been_made.once
            end
          end
        end
      end
    end

    describe 'passing in a single attribute to update' do
      before do
        stub_update service_instance
      end

      context 'arbitrary params are the only change' do
        let(:request_attrs) { { 'parameters' => updated_parameters } }
        let(:old_maintenance_info) { { 'version' => '5.0.0' } }
        let(:old_service_plan) { ServicePlan.make(:v2, service: service, maintenance_info: old_maintenance_info) }

        it 'sends a request to the broker updating only parameters' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance)).with do |req|
              parsed_body = JSON.parse(req.body)

              expect(parsed_body).to include({
                'parameters' => updated_parameters,
                'plan_id' => old_service_plan.broker_provided_id,
                'previous_values' => {
                  'plan_id' => old_service_plan.broker_provided_id,
                  'service_id' => service_instance.service.broker_provided_id,
                  'organization_id' => service_instance.organization.guid,
                  'space_id' => service_instance.space.guid,
                  'maintenance_info' => old_maintenance_info,
                }
              })
              expect(parsed_body).not_to include('maintenance_info')
            end
          ).to have_been_made.once
        end

        it 'updates only last operation on service_instance and keeps all other attributes same' do
          original_service_instance = service_instance.to_hash

          service_instance_update.update_service_instance(service_instance, request_attrs)

          updated_service_instance = service_instance.reload.to_hash

          expect(original_service_instance['last_operation']).to be_nil
          expect(updated_service_instance['last_operation']).to include('type' => 'update', 'state' => 'succeeded')

          expect(updated_service_instance.except('last_operation')).
            to eq(original_service_instance.except('last_operation'))
        end
      end

      context 'plan is the only attr passed in' do
        context "but didn't change" do
          let(:request_attrs) { { 'service_plan_guid' => old_service_plan.guid } }

          it 'should not update the broker' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(
              a_request(:patch, update_url(service_instance)).with(
                body: hash_including({
                  'plan_id' => old_service_plan.broker_provided_id,
                  'previous_values' => {
                    'plan_id' => old_service_plan.broker_provided_id,
                    'service_id' => service_instance.service.broker_provided_id,
                    'organization_id' => service_instance.organization.guid,
                    'space_id' => service_instance.space.guid
                  }
                })
              )
            ).to_not have_been_made
          end
        end

        context 'and changed' do
          let(:request_attrs) {
            {
              'service_plan_guid' => new_service_plan.guid
            }
          }

          it 'should update the broker' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(
              a_request(:patch, update_url(service_instance)).with(
                body: hash_including({
                  'plan_id' => new_service_plan.broker_provided_id,
                  'previous_values' => {
                    'plan_id' => old_service_plan.broker_provided_id,
                    'service_id' => service_instance.service.broker_provided_id,
                    'organization_id' => service_instance.organization.guid,
                    'space_id' => service_instance.space.guid
                  }
                })
              )
            ).to have_been_made.once

            expect(service_instance.service_plan).to eq(new_service_plan)
          end

          context 'new plan has maintenance_info' do
            let(:new_plan_maintenance_info) { { 'version' => '1.0', 'extra' => 'something' } }
            let(:maintenance_info_without_extra) { { 'version' => '1.0' } }

            it 'should update the service instance maintenance_info to its new plan maintenance_info' do
              service_instance_update.update_service_instance(service_instance, request_attrs)

              expect(service_instance.reload.maintenance_info).to eq(maintenance_info_without_extra)
            end
          end

          context 'new plan does not have maintenance_info' do
            let(:new_plan_maintenance_info) {}

            it 'should reset the service instance maintenance_info to nil' do
              service_instance.maintenance_info = { 'version' => '0.1' }
              service_instance.save
              service_instance_update.update_service_instance(service_instance, request_attrs)

              expect(service_instance.reload.maintenance_info).to eq(nil)
            end
          end
        end
      end

      context 'name is the only change' do
        let(:request_attrs) { { 'name' => updated_name } }

        context 'allow_context_updates is enabled for service' do
          let(:allow_context_updates) { true }

          it 'sends a request to the broker' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(
              a_request(:patch, update_url(service_instance)).with(
                body: hash_including({
                  'plan_id' => old_service_plan.broker_provided_id,
                  'previous_values' => {
                    'plan_id' => old_service_plan.broker_provided_id,
                    'service_id' => service_instance.service.broker_provided_id,
                    'organization_id' => service_instance.organization.guid,
                    'space_id' => service_instance.space.guid
                  }
                })
              )
            ).to have_been_made.once
          end
        end

        context 'allow_context_updates is disabled for service' do
          let(:allow_context_updates) { false }

          it 'does not send a request to the broker' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(
              a_request(:patch, update_url(service_instance))).not_to have_been_made
          end
        end
      end
    end

    describe 'updating dashboard urls' do
      let(:broker_body) {}
      let(:stub_opts) { { status: 202, body: broker_body.to_json } }

      before do
        stub_update(service_instance, stub_opts)
      end

      context 'when the service instance already has a dashboard url' do
        before do
          service_instance.dashboard_url = 'http://previous-dashboard-url.com'
          service_instance.save
        end

        context 'and when there is a new dashboard url on update' do
          let(:broker_body) { { operation: '123', dashboard_url: 'http://new-dashboard-url.com' } }

          it 'updates the service instance model with the new url' do
            service_instance_update.update_service_instance(service_instance, request_attrs)
            service_instance.reload

            expect(service_instance.dashboard_url).to eq 'http://new-dashboard-url.com'
          end
        end

        context 'when there is no dashboard url on update' do
          let(:broker_body) { { operation: '123' } }

          it 'displays the previous dashboard url' do
            service_instance_update.update_service_instance(service_instance, request_attrs)
            service_instance.reload

            expect(service_instance.dashboard_url).to eq 'http://previous-dashboard-url.com'
          end
        end

        context 'when the dashboard url is present' do
          let(:broker_body) { { operation: '123', dashboard_url: '' } }

          it 'updates the service instace model with its value' do
            service_instance_update.update_service_instance(service_instance, request_attrs)
            service_instance.reload

            expect(service_instance.dashboard_url).to eq ''
          end
        end
      end

      context 'when the service instance does not already have a dashboard url' do
        context 'when there is a new dashboard url on update' do
          let(:broker_body) { { operation: '123', dashboard_url: 'http://new-dashboard-url.com' } }

          it 'updates the service instance model with the new url' do
            service_instance_update.update_service_instance(service_instance, request_attrs)
            service_instance.reload

            expect(service_instance.dashboard_url).to eq 'http://new-dashboard-url.com'
          end
        end

        context 'when there is no dashboard url on update' do
          let(:broker_body) { { operation: '123' } }

          it 'does not display a url' do
            service_instance_update.update_service_instance(service_instance, request_attrs)
            service_instance.reload

            expect(service_instance.dashboard_url).to be_nil
          end
        end
      end

      context 'when the dashboard url is not a string' do
        let(:broker_body) { { operation: '123', dashboard_url: {} } }

        it 'fails to update the service instance' do
          expect {
            service_instance_update.update_service_instance(service_instance, request_attrs)
          }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed,
                           %r{The property '#/dashboard_url' .* did not match one or more of the following types: string, null})

          service_instance.reload

          expect(service_instance.dashboard_url).to eq nil
        end
      end
    end

    describe 'updating maintenance_info' do
      let(:new_maintenance_info) {
        {
          'version' => '2.0',
        }
      }

      let(:old_maintenance_info) {
        {
          'version' => '1.0',
        }
      }

      let(:request_attrs) {
        {
          'maintenance_info' => new_maintenance_info,
        }
      }

      let(:broker_body) { {} }
      let(:stub_opts) { { status: 200, body: broker_body.to_json } }
      let(:service_instance) { ManagedServiceInstance.make(maintenance_info: old_maintenance_info) }

      before do
        stub_update(service_instance, stub_opts)
      end

      it 'sends maintenance_info to the broker' do
        service_instance_update.update_service_instance(service_instance, request_attrs)

        expect(
          a_request(:patch, update_url(service_instance)).with do |req|
            expect(JSON.parse(req.body)).to include({
              'maintenance_info' => new_maintenance_info,
              'previous_values' => {
                'plan_id' => service_instance.service_plan.broker_provided_id,
                'service_id' => service_instance.service.broker_provided_id,
                'organization_id' => service_instance.organization.guid,
                'space_id' => service_instance.space.guid,
                'maintenance_info' => old_maintenance_info,
              }
            })
          end
        ).to have_been_made.once
      end

      context 'previous values when maintenance_info is nil' do
        let(:old_maintenance_info) { nil }

        it 'does not include it in the previous_values' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance)).with do |req|
              expect(JSON.parse(req.body)).not_to include({
                'previous_values' => have_key('maintenance_info'),
              })
            end
          ).to have_been_made.once
        end
      end

      context 'when the maintenance_info has extra fields' do
        let(:new_maintenance_info) {
          {
            'version' => '2.0',
            'extra' => 'some extra information',
          }
        }
        let(:maintenance_info_without_extra) { { 'version' => '2.0' } }

        let(:old_maintenance_info) {
          {
            'version' => '1.0',
            'extra' => 'some extra information',
          }
        }
        let(:old_maintenance_info_without_extra) { { 'version' => '1.0' } }

        it 'sends maintenance_info to the broker without the extra fields' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance)).with do |req|
              expect(JSON.parse(req.body)).to include({
                'maintenance_info' => maintenance_info_without_extra,
                'previous_values' => include(
                  'maintenance_info' => old_maintenance_info_without_extra,
                ),
              })
            end
          ).to have_been_made.once
        end

        context 'when the broker responds synchronously' do
          it 'updates the service instance maintenance_info in the model' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            service_instance.reload

            expect(service_instance.maintenance_info).to eq(maintenance_info_without_extra)
          end
        end

        context 'when the broker responds asynchronously' do
          let(:service_instance_update) do
            ServiceInstanceUpdate.new(
              accepts_incomplete: true,
              services_event_repository: services_event_repo
            )
          end

          before do
            stub_update(service_instance, accepts_incomplete: true, status: 202)
          end

          it 'saves the new maintenance_info as a proposed change' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(service_instance.last_operation.proposed_changes).to include({ maintenance_info: maintenance_info_without_extra })
          end
        end
      end

      context 'when the maintenance_info.version provided is the same as the one on the service instance' do
        let(:service_instance) { ManagedServiceInstance.make(maintenance_info: new_maintenance_info.merge({ description: 'some description' })) }

        it 'does NOT make a call to the broker' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance))).not_to have_been_made
        end
      end

      context 'when maintenance_info.version provided and does not exist on service_instance' do
        let(:service_instance) { ManagedServiceInstance.make(maintenance_info: nil) }

        it 'updates the broker with new maintenance_info' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance)).with do |req|
              expect(JSON.parse(req.body)).to include({
                'maintenance_info' => new_maintenance_info,
              })
            end
          ).to have_been_made.once
        end
      end

      context 'when the broker responds synchronously' do
        it 'updates the service instance maintenance_info in the model' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          service_instance.reload

          expect(service_instance.maintenance_info).to eq(new_maintenance_info)
        end

        context 'when the broker returns an error' do
          before do
            stub_update(service_instance, status: 418)
          end

          it 'keeps the old maintenance_info' do
            expect {
              service_instance_update.update_service_instance(service_instance, request_attrs)
            }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerRequestRejected)

            service_instance.reload
            expect(service_instance.maintenance_info).to eq(old_maintenance_info)
          end
        end
      end

      context 'when the broker responds asynchronously' do
        let(:service_instance_update) do
          ServiceInstanceUpdate.new(
            accepts_incomplete: true,
            services_event_repository: services_event_repo
          )
        end

        before do
          stub_update(service_instance, accepts_incomplete: true, status: 202)
        end

        it 'keeps the old maintenance_info before the operation is completed' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(service_instance.maintenance_info).to eq(old_maintenance_info)
        end

        it 'saves the new maintenance_info as a proposed change' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(service_instance.last_operation.proposed_changes).to include({ maintenance_info: new_maintenance_info })
        end

        context 'when maintenance_info is present both in the request and from the new plan' do
          let(:new_plan_maintenance_info) { { 'version' => '1.0' } }
          let(:request_attrs) {
            {
              'service_plan_guid' => new_service_plan.guid,
              'maintenance_info' => new_maintenance_info,
            }
          }

          it 'uses the maintenance_info from the new service plan' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(service_instance.last_operation.proposed_changes).to include({ maintenance_info: new_plan_maintenance_info })
          end
        end

        context 'when maintenance_info is missing from the request body' do
          let(:request_attrs) { { 'service_plan_guid' => new_service_plan.guid } }

          context 'but the new plan has a maintenance_info' do
            let(:new_plan_maintenance_info) { { 'version' => '1.0', 'extra' => 'some extra' } }
            let(:maintenance_info_without_extra) { { 'version' => '1.0' } }

            it 'saves the new plan maintenance_info as a proposed change' do
              service_instance_update.update_service_instance(service_instance, request_attrs)

              expect(service_instance.last_operation.proposed_changes).to include({ maintenance_info: maintenance_info_without_extra })
            end

            it 'sends the new plan maintenance_info to the broker' do
              service_instance_update.update_service_instance(service_instance, request_attrs)

              expect(
                a_request(:patch, update_url(service_instance, accepts_incomplete: true)).with do |req|
                  expect(JSON.parse(req.body)).to include({
                    'maintenance_info' => maintenance_info_without_extra,
                    'previous_values' => {
                      'plan_id' => service_instance.service_plan.broker_provided_id,
                      'service_id' => service_instance.service.broker_provided_id,
                      'organization_id' => service_instance.organization.guid,
                      'space_id' => service_instance.space.guid,
                      'maintenance_info' => maintenance_info_without_extra,
                    }
                  })
                end
              ).to have_been_made.once
            end
          end
        end

        context 'when maintenance_info is missing from the body and no plan changed' do
          let(:request_attrs) {
            {
              'parameters' => updated_parameters,
              'name' => updated_name,
              'tags' => updated_tags,
            }
          }

          it 'remains unchanged in the model' do
            service_instance_update.update_service_instance(service_instance, request_attrs)

            expect(service_instance.reload.maintenance_info).to eq(old_maintenance_info)
          end
        end
      end
    end

    context 'when accepts_incomplete is true' do
      let(:service_instance_update) do
        ServiceInstanceUpdate.new(
          accepts_incomplete: true,
          services_event_repository: services_event_repo
        )
      end

      context 'when the broker responds asynchronously' do
        before do
          stub_update(service_instance, accepts_incomplete: true, status: 202)
        end

        it 'creates audit log event start_update' do
          expect(services_event_repo).to receive(:record_service_instance_event).with(:start_update, service_instance, request_attrs).once

          service_instance_update.update_service_instance(service_instance, request_attrs)
        end
      end
    end
  end
end
