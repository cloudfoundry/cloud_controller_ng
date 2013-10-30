require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }

    subject(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, auth_username: auth_username, auth_password: auth_password) }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :auth_password }
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

      it 'validates the auth_username is present' do
        expect(broker).to be_valid
        broker.auth_username = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:auth_username)).to include(:presence)
      end

      it 'validates the auth_password is present' do
        expect(broker).to be_valid
        broker.auth_password = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:auth_password)).to include(:presence)
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
      let(:broker_catalog_url) { "http://#{auth_username}:#{auth_password}@cf-service-broker.example.com/v2/catalog" }

      let(:service_id) { Sham.guid }
      let(:service_name) { Sham.name }
      let(:service_description) { Sham.description }

      let(:plan_id) { Sham.guid }
      let(:plan_name) { Sham.name }
      let(:plan_description) { Sham.description }
      let(:service_metadata_hash) do
        {'metadata' => {'foo' => 'bar'}}
      end
      let(:plan_metadata_hash) do
        {'metadata' => { "cost" => "0.0" }}
      end

      let(:catalog) do
        {
          'services' => [
            {
              'id' => service_id,
              'name' => service_name,
              'description' => service_description,
              'bindable' => true,
              'tags' => ['mysql', 'relational'],
              'plans' => [
                {
                  'id' => plan_id,
                  'name' => plan_name,
                  'description' => plan_description,
                }.merge(plan_metadata_hash)
              ]
            }.merge(service_metadata_hash)
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
        expect(service.tags).to match_array(['mysql', 'relational'])
        expect(JSON.parse(service.extra)).to eq( {'foo' => 'bar'} )
      end

      context 'when catalog service metadata is nil' do
        let(:service_metadata_hash) { {'metadata' => nil} }

        it 'leaves the extra field as nil' do
          broker.load_catalog
          service = Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the catalog service has no metadata key' do
        let(:service_metadata_hash) { {} }

        it 'leaves the extra field as nil' do
          broker.load_catalog
          service = Service.last
          expect(service.extra).to be_nil
        end
      end


      it 'creates plans from the catalog' do
        expect {
          broker.load_catalog
        }.to change(ServicePlan, :count).by(1)

        plan = ServicePlan.last
        expect(plan.service).to eq(Service.last)
        expect(plan.name).to eq(plan_name)
        expect(plan.description).to eq(plan_description)
        expect(JSON.parse(plan.extra)).to eq({ 'cost' => '0.0' })

        # This is a temporary default until cost information is collected from V2
        # services.
        expect(plan.free).to be_true
      end

      context 'when the catalog service plan metadata is empty' do
        let(:plan_metadata_hash) { {'metadata' => nil} }

        it 'leaves the plan extra field as nil' do
          broker.load_catalog
          plan = ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when the catalog service plan has no metadata key' do
        let(:plan_metadata_hash) { {} }

        it 'leaves the plan extra field as nil' do
          broker.load_catalog
          plan = ServicePlan.last
          expect(plan.extra).to be_nil
        end
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

        context 'and the catalog has no plans' do
          let(:catalog) do
            {
              'services' => [
                {
                  'id' => service_id,
                  'name' => service_name,
                  'description' => service_description,
                  'bindable' => true,
                  'tags' => ['mysql', 'relational'],
                  'plans' => []
                }
              ]
            }
          end

          it 'marks the service as inactive' do
            expect(service.active?).to be_true
            broker.load_catalog
            service.reload
            expect(service.active?).to be_false
          end
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

        context 'and a plan exists that has been removed from the broker catalog' do
          let!(:plan) do
            ServicePlan.make(
              service: service,
              unique_id: 'nolongerexists'
            )
          end

          it 'deletes the plan from the db' do
            broker.load_catalog
            expect(ServicePlan.find(:id => plan.id)).to be_nil
          end

          context 'when an instance for the plan exists' do
            it 'marks the existing plan as inactive' do
              ManagedServiceInstance.make(service_plan: plan)
              expect(plan).to be_active

              broker.load_catalog
              plan.reload

              expect(plan).not_to be_active
            end
          end
        end
      end

      context 'when a service no longer exists' do
        let!(:service) do
          Service.make(
            service_broker: broker,
            unique_id: 'nolongerexists'
          )
        end

        it 'should delete the service' do
          broker.load_catalog
          expect(Service.find(:id => service.id)).to be_nil
        end

        context 'but it has an active plan' do
          let!(:plan) do
            ServicePlan.make(
              service: service,
              unique_id: 'also_no_longer_in_catalog'
            )
          end
          let!(:service_instance) do
            ManagedServiceInstance.make(service_plan: plan)
          end

          it 'marks the existing service as inactive' do
            expect(service).to be_active

            broker.load_catalog
            service.reload

            expect(service).not_to be_active
          end
        end

      end
    end

    describe '#client' do
      it 'returns a client created with the correct arguments' do
        v2_client = double('client')
        ServiceBroker::V2::Client.should_receive(:new).with(url: broker_url, auth_username: auth_username, auth_password: auth_password).and_return(v2_client)
        expect(broker.client).to be(v2_client)
      end
    end

    describe "#destroy" do
      let(:service_broker) { ServiceBroker.make }

      it "destroys all services associated with the broker" do
        service = Service.make(:service_broker => service_broker)
        expect {
          begin
            service_broker.destroy(savepoint: true)
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
              service_broker.destroy(savepoint: true)
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
