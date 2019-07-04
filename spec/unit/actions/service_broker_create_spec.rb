require 'spec_helper'
require 'actions/service_broker_create'

module VCAP::CloudController
  RSpec.describe 'V3::ServiceBrokerCreate' do
    let(:service_event_repository) { double }
    let(:service_manager) { double }
    let(:registration) { instance_double(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration) }
    let(:warnings) { [] }
    let(:space_guid) { nil }

    let(:message) do
      params = {
        name: 'broker name',
        url: 'http://example.org/broker-url',
        credentials: {
          type: 'basic',
          data: {
            username: 'broker username',
            password: 'broker password',
          }
        }
      }

      if space_guid
        params[:relationships] = { space: { data: { guid: space_guid } } }
      end

      ServiceBrokerCreateMessage.new(params)
    end

    let(:result) { V3::ServiceBrokerCreate.new(service_event_repository, service_manager).create(message) }

    before do
      allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new).
        and_return(registration)
    end

    context 'when there are no errors on registration' do
      before do
        allow(registration).to receive(:create).and_return(registration)
        allow(registration).to receive(:warnings).and_return(warnings)
      end

      context 'when route and volume service is enabled' do
        before do
          TestConfig.config[:route_services_enabled] = true
          TestConfig.config[:volume_services_enabled] = true
          result
        end

        it 'delegates to ServiceBrokerRegistration with correct params' do
          expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new) do |broker, manager, repo, route_services_enabled, volume_services_enabled|
            expect(broker.broker_url).to eq(message.url)
            expect(broker.name).to eq(message.name)
            expect(broker.auth_username).to eq(message.credentials_data.username)
            expect(broker.auth_password).to eq(message.credentials_data.password)
            expect(manager).to eq(service_manager)
            expect(repo).to eq(service_event_repository)
            expect(route_services_enabled).to be_truthy
            expect(volume_services_enabled).to be_truthy
          end
        end
      end

      context 'when route and volume service is disabled' do
        before do
          TestConfig.config[:route_services_enabled] = false
          TestConfig.config[:volume_services_enabled] = false
          result
        end

        it 'delegates to ServiceBrokerRegistration with correct params' do
          expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new) do |_, _, _, route_services_enabled, volume_services_enabled|
            expect(route_services_enabled).to be_falsey
            expect(volume_services_enabled).to be_falsey
          end
          expect(registration).to have_received(:create)
        end
      end

      context 'when the broker is space scoped' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:space_guid) { space.guid }

        before do
          result
        end

        it 'delegates to ServiceBrokerRegistration with correct params' do
          expect(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to have_received(:new) do |broker, _, _, _, _, _|
            expect(broker.space_guid).to eq(space.guid)
          end
          expect(registration).to have_received(:create)
        end
      end

      context 'when there are warnings on registration' do
        let(:warnings) { %w(warning-1 warning-2) }

        it 'returns warnings in the result' do
          expect(result).to eq(warnings: warnings)
        end
      end

      context 'when there are no warnings on registration' do
        let(:warnings) { [] }
        it 'returns warnings in the result' do
          expect(result).to eq(warnings: [])
        end
      end
    end

    context 'when there are errors on registration' do
      before do
        allow(VCAP::Services::ServiceBrokers::ServiceBrokerRegistration).to receive(:new) do |broker|
          broker.errors[:name] = [:unique]
          registration
        end

        allow(registration).to receive(:create).and_return(nil)
      end

      it 'throws an InvalidServiceBroker exception' do
        expect { result }.to raise_error(V3::ServiceBrokerCreate::InvalidServiceBroker)
      end
    end
  end
end
