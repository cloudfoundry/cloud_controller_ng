require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:token) { 'abc123' }

    subject(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, token: token) }

    before do
      reset_database
    end

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :token }
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

      it 'validates the url is a valid http/https url' do
        expect(broker).to be_valid

        broker.broker_url = '127.0.0.1/api'
        expect(broker).to_not be_valid

        broker.broker_url = 'ftp://127.0.0.1/api'
        expect(broker).to_not be_valid

        broker.broker_url = 'http://127.0.0.1/api'
        expect(broker).to be_valid

        broker.broker_url = 'https://127.0.0.1/api'
        expect(broker).to be_valid
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
              'bindable' => true,
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
        expect(service.bindable).to be_true
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
    end

    describe '#client' do
      it 'returns a client created with the correct arguments' do
        v2_client = double('client')
        ServiceBroker::V2::Client.should_receive(:new).with(url: broker_url, auth_token: token).and_return(v2_client)
        expect(broker.client).to be(v2_client)
      end
    end

    describe "#destroy" do
      let(:service_broker) { ServiceBroker.make }

      it "destroys all services associated with the broker" do
        service = Service.make(:service_broker => service_broker)
        expect {
          begin
            service_broker.destroy
          rescue Sequel::ForeignKeyConstraintViolation
          end
        }.to change {
          Service.where(:id => service.id).any?
        }.to(false)
      end

      context 'when a service instance exists' do
        it 'does not allow the broker to be destroyed' do
          service = Service.make(:service_broker => service_broker)
          service_plan = ServicePlan.make(:service => service)
          ManagedServiceInstance.make(:service_plan => service_plan)
          expect {
            begin
              service_broker.destroy
            rescue Sequel::ForeignKeyConstraintViolation
            end
          }.to_not change {
            Service.where(:id => service.id).count
          }.by(-1)
        end
      end
    end
  end
end
