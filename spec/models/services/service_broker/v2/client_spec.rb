require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker::V2::Client do
    let(:service_broker) { ServiceBroker.make }

    subject(:client) do
      ServiceBroker::V2::Client.new(
        url: service_broker.broker_url,
        auth_username: service_broker.auth_username,
        auth_password: service_broker.auth_password,
      )
    end

    let(:http_client) { double('http_client') }

    before do
      ServiceBroker::V2::HttpClient.stub(:new).
        with(url: service_broker.broker_url, auth_username: service_broker.auth_username, auth_password: service_broker.auth_password).
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
      let(:space) { Space.make }
      let(:instance) do
        ManagedServiceInstance.new(
          service_plan: plan,
          space: space
        )
      end

      let(:response) do
        {
          'dashboard_url' => 'foo'
        }
      end

      before do
        http_client.stub(:provision).and_return(response)
      end

      it 'sends the correct request to the http client' do
        client.provision(instance)

        expect(http_client).to have_received(:provision).with(
          instance_id: instance.guid,
          plan_id: plan.broker_provided_id,
          org_guid: space.organization.guid,
          space_guid: space.guid,
          service_id: plan.service.broker_provided_id,
        )
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
        http_client.stub(:bind).and_return(response)
      end

      it 'sends the correct request to the http client' do
        client.bind(binding)

        expect(http_client).to have_received(:bind).with(
          binding_id: binding.guid,
          instance_id: instance.guid,
          service_id: instance.service.broker_provided_id,
          plan_id: instance.service_plan.broker_provided_id,
        )
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
          binding_options: { 'this' => 'that' }
        )
      end

      before do
        http_client.stub(:unbind)
      end

      it 'unbinds the service' do
        client.unbind(binding)

        expect(http_client).to have_received(:unbind).with(
          binding_id: binding.guid,
          instance_id: binding.service_instance.guid,
          service_id: binding.service.broker_provided_id,
          plan_id: binding.service_plan.broker_provided_id,
        )
      end
    end

    describe '#deprovision' do
      let(:instance) { ManagedServiceInstance.make }

      before do
        http_client.stub(:deprovision)
      end

      it 'deprovisions the service' do
        client.deprovision(instance)

        expect(http_client).to have_received(:deprovision).with(
          instance_id: instance.guid,
          service_id: instance.service.broker_provided_id,
          plan_id: instance.service_plan.broker_provided_id,
        )
      end
    end
  end

end
