require 'spec_helper'
require 'actions/v3/service_plan_visibility_update'
require 'messages/service_plan_visibility_update_message'

module VCAP
  module CloudController
    module V3
      RSpec.describe 'ServicePlanVisibilityUpdate' do
        let(:subject) { ServicePlanVisibilityUpdate.new }

        describe 'update' do
          context 'when the plan visibility is currently "admin"' do
            let(:service_plan) { ServicePlan.make(public: false) }

            context 'and its being updated to "public"' do
              let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'public' }) }

              it 'updates the visibility' do
                updated_visibility = subject.update(service_plan, message)
                expect(updated_visibility.reload.visibility_type).to eq 'public'
              end
            end
          end

          context 'when the plan visibility is currently "public"' do
            let(:service_plan) { ServicePlan.make(public: false) }

            context 'and its being updated to "admin"' do
              let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'admin' }) }

              it 'updates the visibility' do
                updated_visibility = subject.update(service_plan, message)
                expect(updated_visibility.reload.visibility_type).to eq 'admin'
              end
            end
          end

          context 'when the plan visibility is currently "space"' do
            let(:service_plan) do
              ServicePlan.make(
                service: Service.make(
                  service_broker: ServiceBroker.make(space: Space.make)
                )
              )
            end
            let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'admin' }) }

            it 'fails to update' do
              expect {
                subject.update(service_plan, message)
              }.to raise_error(ServicePlanVisibilityUpdate::Error, 'cannot update plans with visibility type \'space\'')

              expect(service_plan.reload.visibility_type).to eq 'space'
            end
          end

          context 'when the message is invalid' do
            let(:service_plan) { ServicePlan.make(public: false) }
            let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'what' }) }

            it 'errors nicely' do
              expect {
                subject.update(service_plan, message)
              }.to raise_error(ServicePlanVisibilityUpdate::Error, "Type must be one of 'public', 'admin', 'organization'")
            end
          end

          context 'when the model fails to update' do
            let(:service_plan) { ServicePlan.make(public: false) }
            let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'public' }) }

            before do
              errors = Sequel::Model::Errors.new
              errors.add(:type, 'is invalid')
              expect(service_plan).to receive(:save).
                and_raise(Sequel::ValidationFailed.new(errors))
            end

            it 'errors' do
              expect {
                subject.update(service_plan, message)
              }.to raise_error(ServicePlanVisibilityUpdate::Error, 'type is invalid')
            end
          end
        end
      end
    end
  end
end
