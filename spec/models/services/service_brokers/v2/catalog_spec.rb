require 'spec_helper'

require 'models/services/service_brokers/v2/catalog'

module VCAP::CloudController::ServiceBrokers::V2
  describe Catalog do
    let(:broker) { VCAP::CloudController::ServiceBroker.make }

    def service_entry(opts = {})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
        'bindable'    => true,
        'tags'        => ['magical', 'webscale'],
        'plans'       => opts[:plans] || [plan_entry]
      }
    end

    def plan_entry(opts={})
      {
        'id'          => opts[:id] || Sham.guid,
        'name'        => opts[:name] || Sham.name,
        'description' => Sham.description,
      }
    end

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
    let(:dashboard_client_attrs) do
      {
        'id' => 'abcde123',
        'secret' => 'sekret',
        'redirect_uri' => 'http://example.com'
      }
    end

    let(:catalog_hash) do
      {
        'services' => [
          {
            'id'          => service_id,
            'name'        => service_name,
            'description' => service_description,
            'bindable'    => true,
            'dashboard_client' => dashboard_client_attrs,
            'tags'        => ['mysql', 'relational'],
            'requires'    => ['ultimate', 'power'],
            'plans'       => [
              {
                'id'          => plan_id,
                'name'        => plan_name,
                'description' => plan_description,
              }.merge(plan_metadata_hash)
            ]
          }.merge(service_metadata_hash)
        ]
      }
    end

    let(:catalog) { Catalog.new(broker, catalog_hash) }

    describe '#sync_services_and_plans' do
      it 'creates services from the catalog' do
        expect {
          catalog.sync_services_and_plans
        }.to change(VCAP::CloudController::Service, :count).by(1)

        service = VCAP::CloudController::Service.last
        expect(service.service_broker).to eq(broker)
        expect(service.label).to eq(service_name)
        expect(service.description).to eq(service_description)
        expect(service.bindable).to be_true
        expect(service.tags).to match_array(['mysql', 'relational'])
        expect(JSON.parse(service.extra)).to eq( {'foo' => 'bar'} )
        expect(service.requires).to eq(['ultimate', 'power'])
      end

      context 'when catalog service metadata is nil' do
        let(:service_metadata_hash) { {'metadata' => nil} }

        it 'leaves the extra field as nil' do
          catalog.sync_services_and_plans
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the catalog service has no metadata key' do
        let(:service_metadata_hash) { {} }

        it 'leaves the extra field as nil' do
          catalog.sync_services_and_plans
          service = VCAP::CloudController::Service.last
          expect(service.extra).to be_nil
        end
      end

      context 'when the plan does not exist in the database' do
        it 'creates plans from the catalog' do
          expect {
            catalog.sync_services_and_plans
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)
          expect(JSON.parse(plan.extra)).to eq({ 'cost' => '0.0' })

          # This is a temporary default until cost information is collected from V2
          # services.
          expect(plan.free).to be_true
        end

        it 'marks the plan as private' do
          catalog.sync_services_and_plans
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.public).to be_false
        end
      end

      context 'when the catalog service plan metadata is empty' do
        let(:plan_metadata_hash) { {'metadata' => nil} }

        it 'leaves the plan extra field as nil' do
          catalog.sync_services_and_plans
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when the catalog service plan has no metadata key' do
        let(:plan_metadata_hash) { {} }

        it 'leaves the plan extra field as nil' do
          catalog.sync_services_and_plans
          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.extra).to be_nil
        end
      end

      context 'when a service already exists' do
        let!(:service) do
          VCAP::CloudController::Service.make(
            service_broker: broker,
            unique_id: service_id
          )
        end

        it 'updates the existing service' do
          expect(service.label).to_not eq(service_name)
          expect(service.description).to_not eq(service_description)

          expect {
            catalog.sync_services_and_plans
          }.to_not change(VCAP::CloudController::Service, :count)

          service.reload
          expect(service.label).to eq(service_name)
          expect(service.description).to eq(service_description)
        end

        context 'when the broker is different' do
          let(:different_broker) { VCAP::CloudController::ServiceBroker.make }
          let!(:service) do
            VCAP::CloudController::Service.make(
              service_broker: different_broker,
              unique_id: service_id
            )
          end

          it 'raises a database error' do
            expect {
              catalog.sync_services_and_plans
            }.to raise_error Sequel::ValidationFailed
          end
        end

        it 'creates the new plan' do
          expect {
            catalog.sync_services_and_plans
          }.to change(VCAP::CloudController::ServicePlan, :count).by(1)

          plan = VCAP::CloudController::ServicePlan.last
          expect(plan.service).to eq(VCAP::CloudController::Service.last)
          expect(plan.name).to eq(plan_name)
          expect(plan.description).to eq(plan_description)

          # This is a temporary default until cost information is collected from V2
          # services.
          expect(plan.free).to be_true
        end

        context 'and a plan already exists' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: plan_id
            )
          end

          it 'updates the existing plan' do
            expect(plan.name).to_not eq(plan_name)
            expect(plan.description).to_not eq(plan_description)

            expect {
              catalog.sync_services_and_plans
            }.to_not change(VCAP::CloudController::ServicePlan, :count)

            plan.reload
            expect(plan.name).to eq(plan_name)
            expect(plan.description).to eq(plan_description)
          end

          context 'when the plan is public' do
            before do
              plan.update(public: true)
            end

            it 'does not make it public' do
              catalog.sync_services_and_plans
              plan.reload
              expect(plan.public).to be_true
            end
          end
        end

        context 'and a plan exists that has been removed from the broker catalog' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'nolongerexists'
            )
          end

          it 'deletes the plan from the db' do
            catalog.sync_services_and_plans
            expect(VCAP::CloudController::ServicePlan.find(:id => plan.id)).to be_nil
          end

          context 'when an instance for the plan exists' do
            it 'marks the existing plan as inactive' do
              VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan)
              expect(plan).to be_active

              catalog.sync_services_and_plans
              plan.reload

              expect(plan).not_to be_active
            end
          end
        end
      end

      context 'when a service no longer exists' do
        let!(:service) do
          VCAP::CloudController::Service.make(
            service_broker: broker,
            unique_id: 'nolongerexists'
          )
        end

        it 'should delete the service' do
          catalog.sync_services_and_plans
          expect(VCAP::CloudController::Service.find(:id => service.id)).to be_nil
        end

        context 'but it has an active plan' do
          let!(:plan) do
            VCAP::CloudController::ServicePlan.make(
              service: service,
              unique_id: 'also_no_longer_in_catalog'
            )
          end
          let!(:service_instance) do
            VCAP::CloudController::ManagedServiceInstance.make(service_plan: plan)
          end

          it 'marks the existing service as inactive' do
            expect(service).to be_active

            catalog.sync_services_and_plans
            service.reload

            expect(service).not_to be_active
          end
        end

      end

      describe 'creating dashboard clients for sso' do
        let(:catalog_hash) do
          {
            'services' => [
              {
                'id'          => Sham.guid,
                'name'        => 'service-with-dashboard-client',
                'description' => service_description,
                'bindable'    => true,
                'dashboard_client' => dashboard_client_attrs,
                'tags'        => ['mysql', 'relational'],
                'plans'       => [
                  {
                    'id'          => plan_id,
                    'name'        => plan_name,
                    'description' => plan_description,
                  }.merge(plan_metadata_hash)
                ]
              }.merge(service_metadata_hash),
              {
                'id'          => Sham.guid,
                'name'        => 'service-without-dashboard-client',
                'description' => service_description,
                'bindable'    => true,
                'tags'        => ['mysql', 'relational'],
                'plans'       => [
                  {
                    'id'          => Sham.guid,
                    'name'        => Sham.name,
                    'description' => plan_description,
                  }.merge(plan_metadata_hash)
                ]
              }.merge(service_metadata_hash)
            ]
          }
        end
      end
    end

    describe 'validations' do
      context "when the catalog's services include errors" do
        let(:catalog_hash) do
          {
            'services' => [
              service_entry,
              service_entry(id: 123),
              service_entry(plans: [plan_entry(id: 'plan-id'), plan_entry(id: 'plan-id', name: 123)]),
              service_entry(plans: [])
            ]
          }
        end

        specify '#valid? returns false' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.nested_errors).not_to be_empty
        end
      end

      def build_service(attrs={})
        @index ||= 0
        @index += 1
        {
          "id" =>"#{@index}",
          "name" =>"#{@index}",
          "description" =>"the service description",
          "bindable" =>true,
          "tags" =>["tag1"],
          "metadata" => {"foo" =>"bar"},
          "plans" =>[
            {
              "id" => "#{@index}",
              "name" => "#{@index}",
              "description" => "the plan description",
              "metadata" => {"foo" =>"bar"}
            }
          ]
        }.merge(attrs)
      end

      context 'when two services in the catalog have the same id' do
        let(:catalog_hash) do
          {
            "services" => [build_service('id' => '1'), build_service('id' => '1')]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end
      end

      context 'when two services in the catalog have the same dashboard_client id' do
        let(:catalog_hash) do
          {
            "services" => [
              build_service('dashboard_client' => {
                'id' => 'client-1',
                'secret' => 'secret',
                'redirect_uri' => 'http://example.com/client-1'
              }),
              build_service('dashboard_client' => {
                'id' => 'client-1',
                'secret' => 'secret2',
                'redirect_uri' => 'http://example.com/client-2'
              }),
            ]
          }
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to include('Service dashboard_client ids must be unique')
        end
      end

      context "when a service's dashboard_client attribute is not a hash" do
        let(:catalog_hash) do
          {"services" => [build_service('dashboard_client' => 1)]}
        end

        it 'gives an error' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
        end
      end

      context 'when there are multiple services without a dashboard_client' do
        let(:catalog_hash) do
          {"services" => [build_service, build_service]}
        end

        it 'does not give a uniqueness error on dashboard_client id' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq true
        end
      end

      context 'when there are multiple services with a nil dashboard_client id' do
        let(:catalog_hash) do
          {
            "services" => [
              build_service("dashboard_client" => {"id" => nil}),
              build_service("dashboard_client" => {"id" => nil})
            ]
          }
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are multiple services with an empty id' do
        let(:catalog_hash) do
          {"services" => [build_service('id' => nil), build_service('id' => nil)]}
        end

        it 'is invalid, but not due to uniqueness constraints' do
          catalog = Catalog.new(broker, catalog_hash)
          expect(catalog.valid?).to eq false
          expect(catalog.errors.messages).to eq []
        end
      end

      context 'when there are both service validation problems and uniqueness problems' do
        let(:catalog_hash) do
          {
            "services" => [
              build_service('id' => 'service-1', 'dashboard_client' => {'id' => 'client-1'}),
              build_service('id' => 'service-1', 'dashboard_client' => {'id' => 'client-1'}),
            ]
          }
        end
        let(:catalog) { Catalog.new(broker, catalog_hash) }

        it 'is not valid' do
          expect(catalog).not_to be_valid
        end

        it 'has validation errors on the service' do
          catalog.valid?
          expect(catalog.errors.nested_errors).not_to be_empty
        end

        it 'has a validation error for duplicate service ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service ids must be unique')
        end

        it 'has a validation error for duplicate dashboard_client ids' do
          catalog.valid?
          expect(catalog.errors.messages).to include('Service dashboard_client ids must be unique')
        end
      end
    end
  end
end
