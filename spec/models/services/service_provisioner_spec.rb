require "spec_helper"

module VCAP::CloudController
  describe ServiceProvisioner, type: :model do
    describe "#provision" do
      context 'for a v1 service' do
        it 'provisions the service on the gateway' do
          provision_hash = nil
          VCAP::Services::Api::ServiceGatewayClientFake.any_instance.should_receive(:provision) do |h|
            provision_hash = h
            VCAP::Services::Api::GatewayHandleResponse.new(
              :service_id => '',
              :configuration => '',
              :credentials => '',
              :dashboard_url => 'http://dashboard.io'
            )
          end

          email = Sham.email
          VCAP::CloudController::SecurityContext.stub(:current_user_email) { email }

          service_plan = ServicePlan.make(service: Service.make(service_broker: nil))
          space = Space.make
          name = Sham.name
          service_instance = ManagedServiceInstance.new(
            service_plan: service_plan,
            space: space,
            name: name
          )

          ServiceProvisioner.new(service_instance).provision

          expect(provision_hash).to eq(
            :label => "#{service_plan.service.label}-#{service_plan.service.version}",
            :name => name,
            :email => email,
            :plan => service_plan.name,
            :plan_option => {},
            :provider => service_plan.service.provider,
            :version => service_plan.service.version,
            :unique_id => service_plan.unique_id,
            :space_guid => space.guid,
            :organization_guid => space.organization_guid
          )
        end

        it 'translates duplicate service errors' do
          VCAP::Services::Api::ServiceGatewayClientFake.any_instance.stub(:provision).and_raise(
            VCAP::Services::Api::ServiceGatewayClient::ErrorResponse.new(
              500,
              VCAP::Services::Api::ServiceErrorResponse.new(
                code: 33106,
                description: "AppDirect does not allow multiple instances of edition-based services in a space. AppDirect response: {}"
              )
            )
          )

          service_plan = ServicePlan.make
          space = Space.make
          name = Sham.name
          service_instance = ManagedServiceInstance.new(
            service_plan: service_plan,
            space: space,
            name: name
          )
          provisioner = ServiceProvisioner.new(service_instance)

          expect { provisioner.provision }.to raise_error(
            VCAP::CloudController::Errors::ServiceInstanceDuplicateNotAllowed
          )
        end
      end

      context 'for a v2 service' do
        it 'provisions the service on the gateway' do
          email = Sham.email
          VCAP::CloudController::SecurityContext.stub(:current_user_email) { email }

          service_plan = ServicePlan.make(
            service: Service.make(
              service_broker: ServiceBroker.make
            ),
          )
          space = Space.make
          name = Sham.name
          service_instance = ManagedServiceInstance.new(
            service_plan: service_plan,
            space: space,
            name: name
          )

          broker_instance_id = SecureRandom.uuid

          fake_broker_client = double('broker client')
          fake_broker_client.
            should_receive(:provision).
            with(service_plan.service.broker_id, service_plan.broker_id, service_instance.guid).
            and_return({ id: broker_instance_id })

          provision_response = ServiceProvisioner.new(
            service_instance,
            broker_client: fake_broker_client
          ).provision

          expect(provision_response.gateway_name).to eq(broker_instance_id)
          expect(provision_response.credentials).to eq({})
        end
      end
    end
  end
end
