require 'spec_helper'

require 'models/services/service_broker/v2/catalog'

module VCAP::CloudController::ServiceBroker::V2
  describe Catalog do
    describe '#sync_services_and_plans' do

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

      let(:catalog_hash) do
        {
          'services' => [
            {
              'id'          => service_id,
              'name'        => service_name,
              'description' => service_description,
              'bindable'    => true,
              'tags'        => ['mysql', 'relational'],
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

      let(:broker) { VCAP::CloudController::ServiceBroker.make }
      let(:catalog) { Catalog.new(broker, catalog_hash) }

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
    end

    describe 'validations' do
      let(:broker) { double(VCAP::CloudController::ServiceBroker, errors: double.as_null_object) }

      def service_entry(opts = {plans: [plan_entry]} )
        {
          'id'          => opts[:id] || Sham.guid,
          'name'        => Sham.name,
          'description' => Sham.description,
          'bindable'    => true,
          'tags'        => ['magical', 'webscale'],
          'plans'       => opts.fetch(:plans)
        }
      end

      def plan_entry(opts={id: Sham.guid})
        {
          'id'          => opts.fetch(:id),
          'name'        => Sham.name,
          'description' => Sham.description,
        }
      end

      context 'when a service has no plans' do
        let(:catalog) do
          {
            'services' => [
              service_entry,
              service_entry(plans: [])
            ]
          }
        end

        it 'throws an exception' do
          expect {
            Catalog.new(broker, catalog)
          }.to raise_error(VCAP::Errors::ServiceBrokerCatalogInvalid, /each service must have at least one plan/)
        end
      end

      context 'when the catalog contains duplicate plan ids within a single service' do
        let(:catalog) do
          {
            'services' => [
              service_entry(plans: [
                                     plan_entry(id: 'abc123'),
                                     plan_entry(id: 'abc123'),
                                   ]
              )
            ]
          }
        end

        it 'throws an exception' do
          expect {
            Catalog.new(broker, catalog)
          }.to raise_error(VCAP::Errors::ServiceBrokerCatalogInvalid, /each plan ID must be unique/)
        end
      end
    end
  end
end
