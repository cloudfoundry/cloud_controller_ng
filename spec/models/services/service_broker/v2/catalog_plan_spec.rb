require 'spec_helper'
require 'securerandom'

require 'models/services/service_broker/v2/catalog_plan'
require 'models/services/service_broker/v2/catalog_service'

module VCAP::CloudController::ServiceBroker::V2
  describe CatalogPlan do
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