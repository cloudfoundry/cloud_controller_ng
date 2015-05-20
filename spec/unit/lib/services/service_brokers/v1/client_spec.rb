require 'spec_helper'

module VCAP::Services
  describe ServiceBrokers::V1::Client do
    subject(:client) do
      ServiceBrokers::V1::Client.new(
        url: 'http://broker.example.com',
        auth_token: 'abc123'
      )
    end

    let(:http_client) { double('http_client') }

    before do
      allow(ServiceBrokers::V1::HttpClient).to receive(:new).
        with(url: 'http://broker.example.com', auth_token: 'abc123').
        and_return(http_client)
    end

    describe '#provision' do
      let(:current_user_email) { 'john@example.com' }
      let(:space) { VCAP::CloudController::Space.make }
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:service) { plan.service }
      let(:instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          space: space,
          service_plan: plan
        )
      end

      let(:response) do
        {
          'service_id' => '123',
          'configuration' => { 'setting' => true },
          'credentials' => { 'user' => 'admin', 'pass' => 'secret' },
          'dashboard_url' => 'http://dashboard.example.com'
        }
      end

      before do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user_email).and_return(current_user_email)
        allow(http_client).to receive(:provision).with(
          plan.unique_id,
          instance.name,
          {
            label: "#{service.label}-#{service.version}",
            email: current_user_email,
            plan: plan.name,
            version: service.version,
            provider: service.provider,
            space_guid: space.guid,
            organization_guid: space.organization_guid
          }
        ).and_return(response)
      end

      it 'sets relevant attributes on the instance' do
        attributes = client.provision(instance)
        instance.save_with_new_operation(attributes)

        expect(instance.broker_provided_id).to eq('123')
        expect(instance.gateway_data).to eq('setting' => true)
        expect(instance.credentials).to eq('user' => 'admin', 'pass' => 'secret')
        expect(instance.dashboard_url).to eq('http://dashboard.example.com')
      end

      it 'translates duplicate service errors' do
        response = double(Net::HTTPInternalServerError, {
          code: '500',
          body: {
            code: 33106,
            description: 'AppDirect does not allow multiple instances of edition-based services in a space. AppDirect response: {}'
          }.to_json
        })
        error = HttpResponseError.new('Duplicate service', 'http://broker.example.com/whatever', :POST, response)

        allow(http_client).to receive(:provision).and_raise(error)

        expect {
          client.provision(instance)
        }.to raise_error(VCAP::CloudController::Errors::ApiError, /service is already present in this space/)
      end
    end

    describe '#bind' do
      let(:current_user_email) { 'john@example.com' }
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:plan) { instance.service_plan }
      let(:service) do
        service = plan.service
        service.requires = ['syslog_drain']
        service.save
        service
      end

      let(:app) { VCAP::CloudController::AppFactory.make(space: instance.space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.new(
          service_instance: instance,
          app: app,
          binding_options: { 'this' => 'that' }
        )
      end

      let(:response) do
        {
          'service_id' => '123',
          'configuration' => 'config',
          'credentials' => { 'foo' => 'bar' },
          'syslog_drain_url' => 'drain url',
        }
      end

      before do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user_email).and_return(current_user_email)
        allow(http_client).to receive(:bind).with(
          instance.broker_provided_id,
          app.guid,
          "#{service.label}-#{service.version}",
          current_user_email,
          { 'this' => 'that' }
        ).and_return(response)
      end

      it 'sets relevant attributes of the binding' do
        attributes = client.bind(binding)
        # Ensure attributes correctly saves to the database.
        binding.set_all(attributes)
        binding.save

        expect(binding.broker_provided_id).to eq('123')
        expect(binding.credentials).to eq({ 'foo' => 'bar' })
        expect(binding.gateway_data).to eq('config')
        expect(binding.syslog_drain_url).to eq('drain url')
      end
    end

    describe '#unbind' do
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end
      let(:instance) { binding.service_instance }

      before do
        allow(http_client).to receive(:unbind).with(
          instance.broker_provided_id,
          binding.broker_provided_id,
          binding.binding_options,
        )
      end

      it 'unbinds the service' do
        client.unbind(binding)

        expect(http_client).to have_received(:unbind)
      end
    end

    describe '#deprovision' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }

      before do
        allow(http_client).to receive(:deprovision).with(
          instance.broker_provided_id
        )
      end

      it 'deprovisions the service' do
        client.deprovision(instance)

        expect(http_client).to have_received(:deprovision)
      end

      it 'returns a successful synchronous response' do
        expect(client.deprovision(instance)).to eq({
          last_operation: {
            state: 'succeeded'
          }
        })
      end
    end
  end
end
