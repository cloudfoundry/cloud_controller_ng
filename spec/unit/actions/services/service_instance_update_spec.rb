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
    let(:service) { Service.make(plan_updateable: true, service_broker: service_broker) }
    let(:old_service_plan) { ServicePlan.make(:v2, service: service) }
    let(:new_service_plan) { ServicePlan.make(:v2, service: service) }
    let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan,
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
        'service_plan_guid' => new_service_plan.guid
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

        expect(
          a_request(:patch, update_url(service_instance)).with(
            body: hash_including({
              'parameters' => updated_parameters,
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

        it 'sends a request to the broker updating only parameters' do
          service_instance_update.update_service_instance(service_instance, request_attrs)

          expect(
            a_request(:patch, update_url(service_instance)).with(
              body: hash_including({
                'parameters' => updated_parameters,
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
