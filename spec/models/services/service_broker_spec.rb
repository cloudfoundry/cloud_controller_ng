require 'spec_helper'

module VCAP::CloudController::Models
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:token) { 'abc123' }

    subject(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, token: token) }

    before do
      reset_database
    end

    describe '#valid?' do
      it 'validates the name is present' do
        expect(broker).to be_valid
        broker.name = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:presence)
      end

      it 'validates the url is present' do
        expect(broker).to be_valid
        broker.broker_url = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:presence)
      end

      it 'validates the token is present' do
        expect(broker).to be_valid
        broker.token = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:token)).to include(:presence)
      end

      it 'validates the name is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(name: broker.name)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:unique)
      end

      it 'validates the url is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(broker_url: broker.broker_url)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:unique)
      end
    end

    describe '#load_catalog' do
      let(:broker_catalog_url) { "http://cc:#{token}@cf-service-broker.example.com/v2/catalog" }

      let(:service_id) { Sham.guid }
      let(:service_name) { Sham.name }
      let(:service_description) { Sham.description }

      let(:plan_id) { Sham.guid }
      let(:plan_name) { Sham.name }
      let(:plan_description) { Sham.description }

      let(:catalog) do
        {
          'services' => [
            {
              'id' => service_id,
              'name' => service_name,
              'description' => service_description,
              'plans' => [
                {
                  'id' => plan_id,
                  'name' => plan_name,
                  'description' => plan_description
                }
              ]
            }
          ]
        }
      end
      let(:body) { catalog.to_json }

      before do
        stub_request(:get, broker_catalog_url).to_return(status: 200, body: body)
        broker.save
      end

      it 'fetches the broker catalog' do
        broker.load_catalog
        expect(a_request(:get, broker_catalog_url)).to have_been_made.once
      end

      it 'creates services from the catalog' do
        expect {
          broker.load_catalog
        }.to change(Service, :count).by(1)

        service = Service.last
        expect(service.service_broker).to eq(broker)
        expect(service.label).to eq(service_name)
        expect(service.description).to eq(service_description)

        # This is a temporary default until the binding of V2 services is needed.
        expect(service.bindable).to be_false
      end

      it 'creates plans from the catalog' do
        expect {
          broker.load_catalog
        }.to change(ServicePlan, :count).by(1)

        plan = ServicePlan.last
        expect(plan.service).to eq(Service.last)
        expect(plan.name).to eq(plan_name)
        expect(plan.description).to eq(plan_description)

        # This is a temporary default until cost information is collected from V2
        # services.
        expect(plan.free).to be_true
      end

      context 'when a service already exists' do
        let!(:service) do
          Service.make(
            service_broker: broker,
            unique_id: service_id
          )
        end

        it 'updates the existing service' do
          expect(service.label).to_not eq(service_name)
          expect(service.description).to_not eq(service_description)

          expect {
            broker.load_catalog
          }.to_not change(Service, :count)

          service.reload
          expect(service.label).to eq(service_name)
          expect(service.description).to eq(service_description)
        end

        it 'creates the new plan' do
          expect {
            broker.load_catalog
          }.to change(ServicePlan, :count).by(1)

          plan = ServicePlan.last
          expect(plan.service).to eq(Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)

          # This is a temporary default until cost information is collected from V2
          # services.
          expect(plan.free).to be_true
        end

        context 'and a plan already exists' do
          let!(:plan) do
            ServicePlan.make(
              service: service,
              unique_id: plan_id
            )
          end

          it 'updates the existing plan' do
            expect(plan.name).to_not eq(plan_name)
            expect(plan.description).to_not eq(plan_description)

            expect {
              broker.load_catalog
            }.to_not change(ServicePlan, :count)

            plan.reload
            expect(plan.name).to eq(plan_name)
            expect(plan.description).to eq(plan_description)
          end
        end
      end

      context 'when the API is not reachable' do
        context 'because the host could not be resolved' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(SocketError)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server connection attempt timed out' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::ConnectTimeoutError)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end

        context 'because the server refused our connection' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(Errno::ECONNREFUSED)
          end

          it 'should raise an unreachable error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiUnreachable)
          end
        end
      end

      context 'when the API times out' do
        context 'because the server gave up' do
          before do
            # We have to instantiate the error object to keep WebMock from initializing
            # it with a String message. KeepAliveDisconnected actually takes an optional
            # Session object, which later HTTPClient code attempts to use.
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::KeepAliveDisconnected.new)
          end

          it 'should raise a timeout error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end

        context 'because the client gave up' do
          before do
            stub_request(:get, broker_catalog_url).to_raise(HTTPClient::ReceiveTimeoutError)
          end

          it 'should raise a timeout error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiTimeout)
          end
        end
      end

      context 'when the API returns an invalid response' do
        context 'because of an unexpected status code' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 201, body: body)
          end

          it 'should raise an invalid response error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerCatalogMalformed)
          end
        end

        context 'because of an unexpected body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: '[]')
          end

          it 'should raise an invalid response error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerCatalogMalformed)
          end
        end

        context 'because of an invalid JSON body' do
          before do
            stub_request(:get, broker_catalog_url).to_return(status: 200, body: 'invalid')
          end

          it 'should raise an invalid response error' do
            expect {
              broker.load_catalog
            }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerCatalogMalformed)
          end
        end
      end

      context 'when the API cannot authenticate the client' do
        before do
          stub_request(:get, broker_catalog_url).to_return(status: 401)
        end

        it 'should raise an authentication error' do
          expect {
            broker.load_catalog
          }.to raise_error(VCAP::CloudController::Errors::ServiceBrokerApiAuthenticationFailed)
        end
      end
    end
  end
end
