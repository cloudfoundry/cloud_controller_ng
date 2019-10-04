require 'spec_helper'
require 'actions/service_broker_create'
require 'support/stepper'

module VCAP
  module CloudController
    RSpec.describe 'ServiceBrokerCreate' do
      let(:dummy) { double('dummy').as_null_object }
      subject(:action) { V3::ServiceBrokerCreate.new(dummy, dummy) }

      let(:name) { "broker-name-#{Sham.sequence_id}" }
      let(:broker_url) { 'http://broker-url' }
      let(:auth_username) { 'username' }
      let(:auth_password) { 'password' }

      let(:message) do
        double('create broker message', {
          name: name,
          url: broker_url,
          authentication_credentials: double('credentials', {
            username: auth_username,
            password: auth_password
          }),
          relationships_message: double('relationships', {
            space_guid: nil
          })
        })
      end

      let(:message2) do
        double('create broker message 2', {
          name: "#{name}-2",
          url: broker_url + '2',
          authentication_credentials: double('credentials 2', {
            username: auth_username + '2',
            password: auth_password + '2'
          }),
          relationships_message: double('relationships 2', {
            space_guid: nil
          })
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
      end

      it 'puts it in a SYNCHRONIZING state' do
        action.create(message)

        expect(broker.service_broker_state.state).to eq(ServiceBrokerStateEnum::SYNCHRONIZING)
      end

      describe 'concurrent behaviour', stepper: true do
        let(:stepper) { Stepper.new(self) }

        before do
          stepper.instrument(
            ServiceBroker, :create,
            before: 'start create broker transaction',
            after: 'finish create broker and start create broker state'
          )

          stepper.instrument(
            ServiceBrokerState, :create,
            after: 'finish create broker transaction'
          )
        end

        20.times do |i|
          it "works when parallel brokers are created #{i}", isolation: :truncation do
            stepper.start_thread([
              'start create broker transaction',
              'finish create broker and start create broker state',
              'finish create broker transaction',
            ]) { subject.create(message) }

            stepper.start_thread([
              'start create broker transaction',
              'finish create broker and start create broker state',
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
