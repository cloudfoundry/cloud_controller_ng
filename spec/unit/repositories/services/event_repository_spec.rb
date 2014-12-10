require 'spec_helper'

module VCAP::CloudController
  module Repositories::Services
    describe EventRepository do
      let(:user) { VCAP::CloudController::User.make }
      let(:email) { 'email@example.com' }
      let(:security_context) { double(:security_context, current_user: user, current_user_email: email) }
      let(:logger) { double(:logger, error: nil) }
      let(:repository) { EventRepository.new(security_context, logger) }

      describe "record_service_plan_visibility_event" do
        let(:service_plan_visibility) { VCAP::CloudController::ServicePlanVisibility.make }

        it "creates the event" do
          repository.record_service_plan_visibility_event(:create, service_plan_visibility, {})

          event = Event.find(type: 'audit.service_plan_visibility.create')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_plan_visibility.guid)
          expect(event.actee_type).to eq('service_plan_visibility')
          expect(event.actee_name).to eq("")
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to eq(service_plan_visibility.organization.guid)
          expect(event.metadata).to eq({"service_plan_guid" => service_plan_visibility.service_plan.guid})
        end

        context "when it fails" do
          before do
            allow(Event).to receive(:create).and_raise
          end

          it "logs an error but does not propogate errors" do
            repository.record_service_plan_visibility_event(:create, service_plan_visibility, {})

            event = Event.find(type: 'audit.service_plan_visibility.create')
            expect(event).not_to be
            expect(logger).to have_received(:error)
          end
        end
      end
    end
  end
end
