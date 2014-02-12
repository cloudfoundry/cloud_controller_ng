require 'spec_helper'
require 'securerandom'

require 'models/services/service_broker/v2/catalog_plan'
require 'models/services/service_broker/v2/catalog_service'

module VCAP::CloudController::ServiceBroker::V2
  describe CatalogPlan do
    describe 'validations' do
      def build_valid_plan_attrs(opts = {})
        {
          'id' => opts[:id] || 'broker-provided-plan-id',
          'metadata' => opts[:metadata] || {},
          'name' => opts[:name] || 'service-plan-name',
          'description' => opts[:description] || 'The description of the service plan'
        }
      end

      it 'validates that @broker_provided_id is a string' do
        attrs = build_valid_plan_attrs(id: 123)
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan id must be a string, but has value 123'
      end

      it 'validates that @broker_provided_id is present' do
        attrs = build_valid_plan_attrs
        attrs['id'] = nil
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan id is required'
      end

      it 'validates that @name is a string' do
        attrs = build_valid_plan_attrs(name: 123)
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan name must be a string, but has value 123'
      end

      it 'validates that @name is present' do
        attrs = build_valid_plan_attrs
        attrs['name'] = nil
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan name is required'
      end

      it 'validates that @description is a string' do
        attrs = build_valid_plan_attrs(description: 123)
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan description must be a string, but has value 123'
      end

      it 'validates that @description is present' do
        attrs = build_valid_plan_attrs
        attrs['description'] = nil
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan description is required'
      end

      it 'validates that @metadata is a hash' do
        attrs = build_valid_plan_attrs(metadata: ['list', 'of', 'strings'])
        plan = CatalogPlan.new(double('broker'), attrs)
        plan.valid?

        expect(plan.errors).to include 'Plan metadata must be a hash, but has value ["list", "of", "strings"]'
      end

      describe "#valid?" do
        it 'is false if plan has errors' do
          attrs = build_valid_plan_attrs(metadata: ['list', 'of', 'strings'])
          expect(CatalogPlan.new(double('broker'), attrs).valid?).to be_false
        end
      end
    end

    describe '#cc_plan' do
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let(:cc_service) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let(:plan_broker_provided_id) { SecureRandom.uuid }
      let(:catalog_service) do
        CatalogService.new( service_broker,
          'id' => cc_service.broker_provided_id,
          'name' => 'my-service-name',
          'description' => 'my service description',
          'bindable' => true,
          'plans' => [{
            'id' => plan_broker_provided_id,
            'name' => 'my-plan-name',
            'description' => 'my plan description'
          }]
        )
      end
      let(:catalog_plan) do
        described_class.new(catalog_service,
          'id' => plan_broker_provided_id,
          'name' => 'my-plan-name',
          'description' => 'my plan description',
        )
      end
      context 'when a ServicePlan exists for the same Service with the same broker_provided_id' do
        let!(:cc_plan) do
          VCAP::CloudController::ServicePlan.make(service: cc_service, unique_id: plan_broker_provided_id)
        end

        it 'returns that ServicePlan' do
          catalog_plan.cc_plan.should == cc_plan
        end
      end

      context 'when a ServicePlan exists for a different Service with the same broker_provided_id' do
        before do
          VCAP::CloudController::ServicePlan.make(unique_id: plan_broker_provided_id)
        end

        it 'returns nil' do
          catalog_plan.cc_plan.should be_nil
        end
      end
    end
  end
end
