require 'spec_helper'
require 'service_plan_delete'

module VCAP::CloudController
  RSpec.describe ServicePlanDelete do
    let(:service_plan_model) { ServicePlan.make }

    it 'can delete service plans' do
      subject.delete(service_plan_model)

      expect do
        service_plan_model.reload
      end.to raise_error(Sequel::Error, 'Record not found')
    end

    context 'when the service plan has a service instance' do
      before do
        ManagedServiceInstance.make(service_plan: service_plan_model)
      end

      it 'does not delete the service plan' do
        expect do
          subject.delete(service_plan_model)
        end.to raise_error(
          ServicePlanDelete::AssociationNotEmptyError,
          'Please delete the service_instances associations for your service_plans.'
        )
      end
    end
  end
end
