require 'spec_helper'
require 'actions/service_broker_create'
require 'support/stepper'

module VCAP
  module CloudController
    RSpec.describe 'ServiceBrokerCreate' do
      let(:dummy) { double('dummy').as_null_object }
      let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: Sham.guid }) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_broker_event_with_request)
        allow(dbl).to receive(:user_audit_info).and_return(user_audit_info)
        dbl
      end

      subject(:action) { V3::ServiceBrokerCreate.new(event_repository) }

      let(:name) { "broker-name-#{Sham.sequence_id}" }
      let(:broker_url) { 'http://broker-url' }
      let(:auth_username) { 'username' }
      let(:auth_password) { 'password' }

      let(:request) do
        {
          name: name,
          url: broker_url,
          authentication: {
            type: 'basic',
            credentials: {
              username: auth_username,
              password: auth_password
            }
          },
          metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
          }
        }
      end

      let(:message) { ServiceBrokerCreateMessage.new(request) }

      let(:message2) do
        ServiceBrokerCreateMessage.new({
          name: "#{name}-2",
          url: broker_url + '2',
          authentication: {
            credentials: {
              username: auth_username + '2',
              password: auth_password + '2'
            }
          }
        })
      end

      let(:broker) { ServiceBroker.last }

      it 'creates a broker' do
        action.create(message)

        expect(broker.name).to eq(name)
        expect(broker.broker_url).to eq(broker_url)
        expect(broker.auth_username).to eq(auth_username)
        expect(broker.auth_password).to eq(auth_password)
        expect(broker.space_guid).to eq(nil)

        expect(broker.labels[0].key_name).to eq('potato')
        expect(broker.labels[0].value).to eq('yam')

        expect(broker.annotations[0].key_name).to eq('style')
        expect(broker.annotations[0].value).to eq('mashed')
      end

      it 'puts it in a SYNCHRONIZING state' do
        action.create(message)

        expect(broker.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
      end

      it 'creates and returns a synchronization job' do
        job = action.create(message)[:pollable_job]

        expect(job).to be_a PollableJobModel
        expect(job.operation).to eq('service_broker.catalog.synchronize')
        expect(job.resource_guid).to eq(broker.guid)
        expect(job.resource_type).to eq('service_brokers')
      end

      it 'creates an audit event' do
        action.create(message)

        request[:authentication][:credentials][:password] = '[PRIVATE DATA HIDDEN]'

        expect(event_repository).
          to have_received(:record_broker_event_with_request).with(
            :create,
            instance_of(ServiceBroker),
            request.with_indifferent_access
          )
      end

      describe 'concurrent behaviour', stepper: true do
        let(:stepper) { Stepper.new(self) }

        before do
          stepper.instrument(
            ServiceBroker, :create,
            before: 'start create broker transaction',
            after: 'finish create broker transaction'
          )
        end

        20.times do |i|
          it "works when parallel brokers are created #{i}", isolation: :truncation do
            stepper.start_thread([
              'start create broker transaction',
              'finish create broker transaction',
            ]) { subject.create(message) }

            stepper.start_thread([
              'start create broker transaction',
              'finish create broker transaction',
            ]) { subject.create(message2) }

            stepper.interleave_order
            stepper.print_order
            stepper.run

            expect(stepper.errors).to be_empty
            expect(stepper.steps_left).to be_empty
          end
        end
      end
    end
  end
end
