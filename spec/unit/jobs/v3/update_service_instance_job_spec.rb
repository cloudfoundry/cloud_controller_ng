require 'spec_helper'
require 'jobs/v3/update_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe UpdateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class

        let(:arbitrary_parameters) { {} }
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:service_offering) { Service.make }
        let(:service_plan) {
          ServicePlan.make(
            service: service_offering,
            maintenance_info: { version: '2.0.0' },
            public: true
          )
        }
        let(:service_instance) do
          si = ManagedServiceInstance.make(
            service_plan: service_plan,
            space: space,
            maintenance_info: { version: '2.0.0' }
          )
          si.label_ids = [
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
            VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
          ]
          si.annotation_ids = [
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
            VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
          ]
          si.reload
          si
        end

        let(:metadata) {
          {
            labels: { foo: 'bar', 'pre.fix/to_delete': nil },
            annotations: { baz: 'quz', 'pre.fix/to_delete': nil }
          }
        }
        let(:message) {
          ServiceInstanceUpdateManagedMessage.new({
            tags: %w(foo bar),
            parameters: arbitrary_parameters,
            metadata: metadata,
          })
        }
        let(:previous_values) {
          {
            plan_id: service_plan.broker_provided_id,
            service_id: service_offering.broker_provided_id,
            organization_id: org.guid,
            space_id: space.guid,
            maintenance_info: service_plan.maintenance_info.stringify_keys,
          }
        }
        let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
        let(:subject) { described_class.new(service_instance.guid, user_audit_info: user_audit_info, message: message) }
        let(:update_response) { { some_key: 'some value' } }
        let(:client) { double('BrokerClient', update: update_response) }

        describe '#operation' do
          it 'returns "update"' do
            expect(subject.operation).to eq(:update)
          end
        end

        describe '#operation_type' do
          it 'returns "update"' do
            expect(subject.operation_type).to eq('update')
          end
        end

        describe '#send_broker_request' do
          it 'returns the client response' do
            response = subject.send_broker_request(client)
            expect(response).to eq({ some_key: 'some value' })
          end

          context 'when paramaters are changing' do
            let(:arbitrary_parameters) { { some_data: 'some_value' } }

            it 'calls the broker client with the right arguments' do
              subject.send_broker_request(client)

              expect(client).to have_received(:update).with(
                service_instance,
                service_plan,
                accepts_incomplete: true,
                arbitrary_parameters: { some_data: 'some_value' },
                maintenance_info: nil,
                name: service_instance.name,
                previous_values: previous_values,
              )
            end
          end

          context 'when name is changing' do
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                name: 'new name'
              })
            }
            it 'calls the broker client with the right arguments' do
              subject.send_broker_request(client)

              expect(client).to have_received(:update).with(
                service_instance,
                service_plan,
                name: 'new name',
                accepts_incomplete: true,
                arbitrary_parameters: {},
                maintenance_info: nil,
                previous_values: previous_values,
              )
            end
          end

          context 'when plan has changed' do
            let(:new_service_plan) {
              ServicePlan.make(
                service: service_offering,
                maintenance_info: { version: '2.1.0' },
                public: true
              )
            }
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                relationships: {
                  service_plan: {
                    data: {
                      guid: new_service_plan.guid
                    }
                  }
                }
              })
            }

            it 'calls the broker client with the right arguments' do
              subject.send_broker_request(client)

              expect(client).to have_received(:update).with(
                service_instance,
                new_service_plan,
                accepts_incomplete: true,
                arbitrary_parameters: {},
                maintenance_info: { version: '2.1.0' },
                name: service_instance.name,
                previous_values: previous_values,
              )
            end
          end

          context 'when maintenance info is changing' do
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                maintenance_info: { version: '2.2.0' }
              })
            }

            it 'calls the broker client with the right arguments' do
              subject.send_broker_request(client)

              expect(client).to have_received(:update).with(
                service_instance,
                service_plan,
                accepts_incomplete: true,
                arbitrary_parameters: {},
                maintenance_info: { version: '2.2.0' },
                name: service_instance.name,
                previous_values: previous_values,
              )
            end
          end

          context 'when the service plan no longer exists' do
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                relationships: { service_plan: { data: { guid: 'fake-plan' } } } }
              )
            }
            it 'raises an error' do
              expect { subject.send_broker_request(client) }.to raise_error(
                ::CloudController::Errors::ApiError,
                /The service plan could not be found/
              )
            end
          end
        end

        describe '#operation_succeeded' do
          let(:message) {
            ServiceInstanceUpdateManagedMessage.new({
              tags: %w(foo bar),
              metadata: metadata,
              name: 'new name'
            })
          }

          before do
            subject.send_broker_request(client)
            subject.operation_succeeded
            service_instance.reload
          end

          context 'when dashboard url changed' do
            let(:new_dashboard_url) { 'https://example.com/new-dashboard' }
            let(:update_response) {
              { dashboard_url: new_dashboard_url }
            }

            it 'updates the service instance dashboard url' do
              expect(service_instance.dashboard_url).to eq(new_dashboard_url)
            end
          end

          context 'when maintenance info changed' do
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                maintenance_info: { version: '2.2.0' }
              })
            }

            it 'updates the service instance maintenance info' do
              expect(service_instance.maintenance_info).to eq({ 'version' => '2.2.0' })
            end
          end

          context 'when the service plan changed' do
            let(:new_service_plan) {
              ServicePlan.make(
                service: service_offering,
                maintenance_info: { version: '2.1.0' },
                public: true
              )
            }
            let(:message) {
              ServiceInstanceUpdateManagedMessage.new({
                relationships: {
                  service_plan: {
                    data: {
                      guid: new_service_plan.guid
                    }
                  }
                }
              })
            }

            it 'updates the service instance plan' do
              expect(service_instance.service_plan).to eq(new_service_plan)
            end
          end

          it 'updates the service instance' do
            expect(service_instance.name).to eq('new name')
            expect(service_instance.tags).to eq(%w(foo bar))
            expect(service_instance.service_plan).to eq(service_plan)

            expect(service_instance.labels.map { |l| { prefix: l.key_prefix, key: l.key_name, value: l.value } }).to match_array([
              { prefix: nil, key: 'foo', value: 'bar' },
              { prefix: 'pre.fix', key: 'tail', value: 'fluffy' }
            ])
            expect(service_instance.annotations.map { |a| { prefix: a.key_prefix, key: a.key, value: a.value } }).to match_array([
              { prefix: nil, key: 'baz', value: 'quz' },
              { prefix: 'pre.fix', key: 'fox', value: 'bushy' }
            ])
          end
        end
      end
    end
  end
end
