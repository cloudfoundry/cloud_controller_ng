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
                updated_plan = subject.update(service_plan, message)
                expect(updated_plan.reload.visibility_type).to eq 'public'
              end
            end

            context 'and its being updated do "organization"' do
              let(:org_guid) { Organization.make.guid }
              let(:other_org_guid) { Organization.make.guid }
              let(:params) {
                { type: 'organization', organizations: [{ guid: org_guid }, { guid: other_org_guid }] }
              }
              let(:message) { ServicePlanVisibilityUpdateMessage.new(params) }

              it 'updates the visibility' do
                updated_plan = subject.update(service_plan, message)
                updated_plan.reload

                expect(updated_plan.visibility_type).to eq 'organization'
                visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)

                expect(visible_org_guids).to contain_exactly(org_guid, other_org_guid)
              end
            end
          end

          context 'when the plan visibility is currently "public"' do
            let(:service_plan) { ServicePlan.make(public: false) }

            context 'and its being updated to "admin"' do
              let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'admin' }) }

              it 'updates the visibility' do
                updated_plan = subject.update(service_plan, message)
                expect(updated_plan.reload.visibility_type).to eq 'admin'
              end
            end

            context 'and its being updated do "organization"' do
              let(:org_guid) { Organization.make.guid }
              let(:other_org_guid) { Organization.make.guid }
              let(:params) {
                { type: 'organization', organizations: [{ guid: org_guid }, { guid: other_org_guid }] }
              }
              let(:message) { ServicePlanVisibilityUpdateMessage.new(params) }

              it 'updates the visibility' do
                updated_plan = subject.update(service_plan, message)
                updated_plan.reload

                expect(updated_plan.visibility_type).to eq 'organization'
                visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)

                expect(visible_org_guids).to contain_exactly(org_guid, other_org_guid)
              end
            end
          end

          context 'when the plan visibility is currently "organization"' do
            let(:org) { Organization.make }
            let(:other_org) { Organization.make }

            let(:service_plan) do
              plan = ServicePlan.make(public: false)
              ServicePlanVisibility.make(organization: org, service_plan: plan)
              ServicePlanVisibility.make(organization: other_org, service_plan: plan)
              plan
            end

            context 'and its being updated to "organization"' do
              let(:new_org_guid) { Organization.make.guid }
              let(:params) {
                { type: 'organization', organizations: [{ guid: new_org_guid }] }
              }
              let(:message) { ServicePlanVisibilityUpdateMessage.new(params) }

              it 'replaces the current list of organizations by default' do
                updated_plan = subject.update(service_plan, message)
                expect(updated_plan.reload.visibility_type).to eq 'organization'
                visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)

                expect(visible_org_guids).to contain_exactly(new_org_guid)
              end

              context "when 'append_orgs' is set to false" do
                it 'replaces the current list of organizations' do
                  updated_plan = subject.update(service_plan, message, append_organizations: false)
                  expect(updated_plan.reload.visibility_type).to eq 'organization'
                  visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)

                  expect(visible_org_guids).to contain_exactly(new_org_guid)
                end
              end

              context "when 'append_orgs' is set to true" do
                it 'appends to the current list of organizations' do
                  updated_plan = subject.update(service_plan, message, append_organizations: true)
                  expect(updated_plan.reload.visibility_type).to eq 'organization'
                  visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)
                  expect(visible_org_guids).to contain_exactly(org.guid, other_org.guid, new_org_guid)
                end

                it 'ignores orgs where the visibility is already created' do
                  params[:organizations] << { guid: org.guid }
                  updated_plan = subject.update(service_plan, message, append_organizations: true)
                  expect(updated_plan.reload.visibility_type).to eq 'organization'
                  visible_org_guids = updated_plan.service_plan_visibilities.map(&:organization_guid)
                  expect(visible_org_guids).to contain_exactly(org.guid, other_org.guid, new_org_guid)
                end
              end
            end

            context 'and its being updated to "admin"' do
              let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'admin' }) }

              it 'updates the visibility type and cleans up the visibilities table' do
                updated_plan = subject.update(service_plan, message)
                expect(updated_plan.reload.visibility_type).to eq 'admin'
                expect(updated_plan.service_plan_visibilities).to be_empty
                expect(ServicePlanVisibility.where(service_plan: service_plan).all).to be_empty
              end
            end

            context 'and its being updated to "public"' do
              let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'public' }) }

              it 'updates the visibility type and cleans up the visibilities table' do
                updated_plan = subject.update(service_plan, message)
                expect(updated_plan.reload.visibility_type).to eq 'public'
                expect(updated_plan.service_plan_visibilities).to be_empty
                expect(ServicePlanVisibility.where(service_plan: service_plan).all).to be_empty
              end
            end
          end

          context 'when the plan visibility is currently "space"' do
            let(:service_plan) do
              ServicePlan.make(
                public: false,
                service: Service.make(
                  service_broker: ServiceBroker.make(space: Space.make)
                )
              )
            end
            let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'admin' }) }

            it 'fails to update' do
              expect {
                subject.update(service_plan, message)
              }.to raise_error(ServicePlanVisibilityUpdate::UnprocessableRequest, 'cannot update plans with visibility type \'space\'')

              expect(service_plan.reload.visibility_type).to eq 'space'
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

          context 'when the organization does not exist' do
            let(:service_plan) { ServicePlan.make(public: false) }
            let(:message) { ServicePlanVisibilityUpdateMessage.new({ type: 'organization', organizations: [{ guid: 'some-fake-org' }] }) }

            it 'errors nicely' do
              expect {
                subject.update(service_plan, message)
              }.to raise_error(ServicePlanVisibilityUpdate::Error, 'Could not find Organization with guid: some-fake-org')
            end
          end
        end
      end
    end
  end
end
