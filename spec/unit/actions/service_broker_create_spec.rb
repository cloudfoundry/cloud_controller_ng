require 'spec_helper'
require 'actions/service_broker_create'

module VCAP::CloudController
  RSpec.describe 'V3::ServiceBrokerCreate' do
    let(:service_event_repository) { double }
    let(:service_manager) { double }
    let(:registration) { instance_double(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration) }
    let(:warnings) { [] }
    let(:result) { V3::ServiceBrokerCreate.new(service_event_repository, service_manager).create(
      name: 'broker name',
      url: 'http://example.org/broker-url',
      username: 'broker username',
      password: 'broker password',
    )
    }
    let(:service_broker) { ServiceBroker.last }

    before do
      allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new).
        and_return(registration)

      allow(registration).to receive(:create)
      allow(registration).to receive(:warnings).and_return(warnings)
    end

    it 'creates a service broker and returns empty warnings' do
      result

      expect(service_broker).to include(
        'name' => 'broker name',
        'broker_url' => 'http://example.org/broker-url',
        'auth_username' => 'broker username'
                                )
      expect(service_broker.auth_password).to eq('broker password')
      expect(result).to eq(warnings: [])
    end

    context 'when route and volume service is enabled' do
      before do
        TestConfig.config[:route_services_enabled] = true
        TestConfig.config[:volume_services_enabled] = true
        result
      end

      it 'delegates to ServiceBrokerRegistration with correct params' do
        expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new).
          with(service_broker, service_manager, service_event_repository, true, true)
        expect(registration).to have_received(:create)
      end
    end

    context 'when route and volume service is disabled' do
      before do
        TestConfig.config[:route_services_enabled] = false
        TestConfig.config[:volume_services_enabled] = false
        result
      end

      it 'delegates to ServiceBrokerRegistration with correct params' do
        expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new).
          with(service_broker, service_manager, service_event_repository, false, false)
        expect(registration).to have_received(:create)
      end
    end

    context 'when there are warnings on registration' do
      let(:warnings) { %w(warning-1 warning-2) }

      it 'returns warnings in the result' do
        expect(result).to eq(warnings: warnings)
      end
    end
  end
end
