require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker::V1::Client do
    subject(:client) do
      ServiceBroker::V1::Client.new(
        url: 'http://broker.example.com',
        timeout: 30,
        auth_token: 'abc123'
      )
    end

    let(:http_client) { double('http_client') }

    before do
      request_id = double('request_id')
      VCAP::Request.stub(:current_id).and_return(request_id)
      VCAP::Services::Api::ServiceGatewayClient.stub(:new).
        with('http://broker.example.com', 'abc123', 30, request_id).
        and_return(http_client)
    end

    describe '#provision' do
      let(:current_user_email) { 'john@example.com' }
      let(:space) { Space.make }
      let(:plan) { ServicePlan.make }
      let(:service) { plan.service }
      let(:instance) do
        ManagedServiceInstance.new(
          space: space,
          service_plan: plan
        )
      end

      let(:response) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          service_id: '123',
          configuration: {'setting' => true},
          credentials: {'user' => 'admin', 'pass' => 'secret'},
          dashboard_url: 'http://dashboard.example.com'
        )
      end

      before do
        VCAP::CloudController::SecurityContext.stub(:current_user_email).and_return(current_user_email)
        http_client.stub(:provision).with(
          :label => "#{service.label}-#{service.version}",
          :name  => instance.name,
          :email => current_user_email,
          :plan  => plan.name,
          :version => service.version,
          :provider => service.provider,
          :space_guid => space.guid,
          :organization_guid => space.organization_guid,
          :unique_id => plan.unique_id,

          # DEPRECATED
          :plan_option => {}
        ).and_return(response)
      end

      it 'sets relevant attributes on the instance' do
        client.provision(instance)

        expect(instance.broker_provided_id).to eq('123')
        expect(instance.gateway_data).to eq('setting' => true)
        expect(instance.credentials).to eq('user' => 'admin', 'pass' => 'secret')
        expect(instance.dashboard_url).to eq('http://dashboard.example.com')
      end

      it 'translates duplicate service errors' do
        http_client.stub(:provision).and_raise(
          VCAP::Services::Api::ServiceGatewayClient::ErrorResponse.new(
            500,
            VCAP::Services::Api::ServiceErrorResponse.new(
              code: 33106,
              description: 'AppDirect does not allow multiple instances of edition-based services in a space. AppDirect response: {}'
            )
          )
        )

        expect {
          client.provision(instance)
        }.to raise_error(VCAP::CloudController::Errors::ServiceInstanceDuplicateNotAllowed)
      end
    end

    describe '#bind' do
      let(:current_user_email) { 'john@example.com' }
      let(:instance) { ManagedServiceInstance.make }
      let(:plan) { instance.service_plan }
      let(:service) { plan.service }
      let(:binding) do
        ServiceBinding.new(
          service_instance: instance,
          binding_options: {'this' => 'that'}
        )
      end

      let(:response) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          service_id: '123',
          configuration: 'config',
          credentials: {'foo' => 'bar'},
          syslog_drain_url: 'drain url'
        )
      end

      before do
        VCAP::CloudController::SecurityContext.stub(:current_user_email).and_return(current_user_email)
        http_client.stub(:bind).with(
          service_id: instance.broker_provided_id,
          label: "#{service.label}-#{service.version}",
          email: current_user_email,
          binding_options: {'this' => 'that'}
        ).and_return(response)
      end

      it 'sets relevant attributes of the binding' do
        client.bind(binding)

        expect(binding.broker_provided_id).to eq('123')
        expect(binding.credentials).to eq({ 'foo' => 'bar' })
        expect(binding.gateway_data).to eq('config')
        expect(binding.syslog_drain_url).to eq('drain url')
      end
    end

    describe '#unbind' do
      let(:binding) do
        ServiceBinding.make(
          binding_options: {'this' => 'that'}
        )
      end
      let(:instance) { binding.service_instance }

      before do
        http_client.stub(:unbind).with(
          :service_id      => instance.broker_provided_id,
          :handle_id       => binding.broker_provided_id,
          :binding_options => binding.binding_options,
        )
      end

      it 'unbinds the service' do
        client.unbind(binding)

        expect(http_client).to have_received(:unbind)
      end

      context 'when unbind returns 404' do
        it 'does not raise' do
          ex = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(double(:extract => "Not found!"))
          http_client.stub(:unbind).and_raise(ex)
          expect {
            client.unbind(binding)
          }.to_not raise_error
        end
      end

      context 'when unbind returns a non-404 error' do
        it 'raises an error' do
          ex = VCAP::Services::Api::ServiceGatewayClient::ErrorResponse.new(500, double(:extract => "Not found!"))
          http_client.stub(:unbind).and_raise(ex)
          expect {
            client.unbind(binding)
          }.to raise_error(ex)
        end
      end
    end

    describe '#deprovision' do
      let(:instance) { ManagedServiceInstance.make }

      before do
        http_client.stub(:unprovision).with(
          service_id: instance.broker_provided_id
        )
      end

      it 'deprovisions the service' do
        client.deprovision(instance)

        expect(http_client).to have_received(:unprovision)
      end

      context 'when deprovision returns 404' do
        it 'does not raise' do
          ex = VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse.new(double(:extract => "Not found!"))
          http_client.stub(:unprovision).and_raise(ex)
          expect {
            client.deprovision(instance)
          }.to_not raise_error
        end
      end

      context 'when deprovision returns a non-404 error' do
        it 'raises an error' do
          ex = VCAP::Services::Api::ServiceGatewayClient::ErrorResponse.new(500, double(:extract => "Not found!"))
          http_client.stub(:unprovision).and_raise(ex)
          expect {
            client.deprovision(instance)
          }.to raise_error(ex)
        end
      end
    end
  end
end
