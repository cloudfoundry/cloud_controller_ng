require 'db_spec_helper'
require 'services/service_brokers/user_provided/client'

module VCAP::Services
  RSpec.describe ServiceBrokers::UserProvided::Client do
    subject(:client) { ServiceBrokers::UserProvided::Client.new }

    describe '#provision' do
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

      it 'exists' do
        client.provision(instance)
      end
    end

    describe '#bind' do
      let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

      context 'when binding to an app' do
        let(:binding) do
          VCAP::CloudController::ServiceBinding.make(service_instance: instance)
        end

        it 'sets relevant attributes of the instance' do
          attributes = client.bind(binding)
          # save to the database to ensure attributes match tables
          binding.set(attributes[:binding])
          binding.save

          expect(binding.credentials).to eq(instance.credentials)
          expect(binding.syslog_drain_url).to eq(instance.syslog_drain_url)
        end

        context 'when binding to a service with a route_service_url' do
          let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(:routing) }

          it 'sets relevant attributes of the instance' do
            attributes = client.bind(binding)
            # save to the database to ensure attributes match tables
            binding.set(attributes[:binding])
            binding.save

            expect(binding.credentials).to eq(instance.credentials)
            expect(binding.syslog_drain_url).to eq(instance.syslog_drain_url)
          end
        end
      end

      context 'when binding to a route' do
        let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(:routing) }

        let(:binding) do
          VCAP::CloudController::RouteBinding.make(
            service_instance: instance
          )
        end

        it 'sets relevant attributes of the instance' do
          attributes = client.bind(binding)
          # save to the database to ensure attributes match tables
          binding.set(attributes[:binding])
          binding.save

          expect(binding.route_service_url).to eq(instance.route_service_url)
        end
      end
    end

    describe '#unbind' do
      let(:binding) { double(:service_binding) }

      it 'exists' do
        client.unbind(binding)
      end

      it 'always returns async false' do
        expect(client.unbind(binding)[:async]).to be(false)
      end
    end

    describe '#deprovision' do
      let(:instance) { double(:service_instance) }

      it 'exists' do
        client.deprovision(instance)
      end
    end
  end
end
