require 'spec_helper'
require 'actions/v3/service_broker_create'

module VCAP::CloudController
  RSpec.describe 'V3::ServiceBrokerCreate' do
    let(:service_event_repository) { double }
    let(:service_manager) { double }
    let(:registration) { instance_double(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration) }

    before do
      allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new).
        and_return(registration)

      allow(registration).to receive(:create)

      V3::ServiceBrokerCreate.new(service_event_repository, service_manager).create(
        name: 'broker name',
        url: 'http://example.org/broker-url',
        username: 'broker username',
        password: 'broker password',
      )
    end

    let(:service_broker) { ServiceBroker.last }

    it 'creates a service broker' do
      expect(service_broker).to include(
        'name' => 'broker name',
        'broker_url' => 'http://example.org/broker-url',
        'auth_username' => 'broker username'
      )
      expect(service_broker.auth_password).to eq('broker password')
    end

    it 'delegates to ServiceBrokerRegistration' do
      expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new).
        with(service_broker, service_manager, service_event_repository, true, true)
      expect(registration).to have_received(:create)
    end
  end
end
