require 'spec_helper'
require 'actions/service_broker_create'

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
          credentials_data: double('credentials', {
            username: auth_username,
            password: auth_password
          }),
          relationships_message: double('relationships', {
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
    end
  end
end
