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

      describe '#record_broker_event' do
        let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
        let(:params) do
          {
            name: service_broker.name,
            broker_url: service_broker.broker_url,
            auth_username: service_broker.auth_username,
            auth_password: service_broker.auth_password,
          }
        end

        it 'creates an event' do
          repository.record_broker_event(:create, service_broker, params)

          event = Event.find(type: 'audit.service_broker.create')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service_broker.guid)
          expect(event.actee_type).to eq('broker')
          expect(event.actee_name).to eq(service_broker.name)
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to be_empty
        end

        describe 'the metadata field' do
          it 'only includes param keys that have values' do
            repository.record_broker_event(:create, service_broker, { name: 'new-name'} )
            metadata = Event.first.metadata
            expect(metadata['request']).to include('name' => 'new-name')
            expect(metadata['request']).not_to have_key('broker_url')
            expect(metadata['request']).not_to have_key('auth_username')
            expect(metadata['request']).not_to have_key('auth_password')
          end

          it 'redacts the auth_password field' do
            repository.record_broker_event(:create, service_broker, { auth_password: 'new-passord'} )

            metadata = Event.first.metadata
            expect(metadata['request']).to include('auth_password' => '[REDACTED]')
          end

          context 'when no params are passed in' do
            it 'saves an empty hash' do
              repository.record_broker_event(:create, service_broker, {})

              expect(Event.first.metadata).to eq({})
            end
          end
        end

        context "when it fails" do
          before do
            allow(Event).to receive(:create).and_raise
          end

          it "logs an error but does not propogate errors" do
            repository.record_broker_event(:create, service_broker, {})

            event = Event.find(type: 'audit.service_broker.create')
            expect(event).not_to be
            expect(logger).to have_received(:error)
          end
        end
      end
    end
  end
end
