require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker::UserProvided::Client do
    subject(:client) { ServiceBroker::UserProvided::Client.new }

    describe '#provision' do
      let(:instance) { double(:service_instance) }

      it 'exists' do
        client.provision(instance)
      end
    end

    describe '#bind' do
      let(:instance) { UserProvidedServiceInstance.make }
      let(:binding) do
        ServiceBinding.new(
          service_instance: instance
        )
      end

      it 'sets relevant attributes of the instance' do
        client.bind(binding)

        expect(binding.credentials).to eq(instance.credentials)
        expect(binding.syslog_drain_url).to eq(instance.syslog_drain_url)
      end
    end

    describe '#unbind' do
      let(:binding) { double(:service_binding) }

      it 'exists' do
        client.unbind(binding)
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
