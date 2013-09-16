require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker::V2::Client do
    let(:service_broker) { ServiceBroker.make }

    subject(:client) do
      ServiceBroker::V2::Client.new(
        url: service_broker.broker_url,
        auth_token: service_broker.token
      )
    end

    let(:http_client) { double('http_client') }

    before do
      ServiceBroker::V2::HttpClient.stub(:new).
        with(url: service_broker.broker_url, auth_token: service_broker.token).
        and_return(http_client)
    end

    describe '#catalog' do
      let(:catalog) { double('catalog') }

      before do
        http_client.stub(:catalog).and_return(catalog)
      end

      it 'returns the catalog' do
        expect(client.catalog).to be(catalog)
      end
    end

    describe '#provision' do
      let(:plan) { ServicePlan.make }
      let(:instance) do
        ManagedServiceInstance.new(
          service_plan: plan
        )
      end

      let(:response) do
        {
          'dashboard_url' => 'foo'
        }
      end

      before do
        http_client.stub(:provision).with(instance.guid, plan.broker_provided_id).and_return(response)
      end

      it 'sets relevant attributes of the instance' do
        client.provision(instance)

        expect(instance.dashboard_url).to eq('foo')
      end
    end

    describe '#bind' do
      let(:instance) { ManagedServiceInstance.make }
      let(:binding) do
        ServiceBinding.new(
          service_instance: instance
        )
      end

      let(:response) do
        {
          'credentials' => {
            'username' => 'admin',
            'password' => 'secret'
          }
        }
      end

      before do
        http_client.stub(:bind).with(binding.guid, instance.guid).and_return(response)
      end

      it 'sets relevant attributes of the instance' do
        client.bind(binding)

        expect(binding.credentials).to eq({
          'username' => 'admin',
          'password' => 'secret'
        })
      end
    end

    describe '#unbind' do
      let(:binding) do
        ServiceBinding.make(
            binding_options: {'this' => 'that'}
        )
      end

      it 'unbinds the service' do
        http_client.should_receive(:unbind).with(binding.guid)

        client.unbind(binding)
      end
    end

    describe '#deprovision' do
      let(:instance) { ManagedServiceInstance.make }

      it 'deprovisions the service' do
        http_client.should_receive(:deprovision).with(instance.guid)

        client.deprovision(instance)
      end
    end
  end

end
