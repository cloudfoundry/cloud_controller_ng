require 'spec_helper'
require 'service_offering_delete'

module VCAP::CloudController
  RSpec.describe ServiceOfferingDelete do
    let(:service_offering_model) { Service.make }

    it 'can delete service offerings' do
      subject.delete(service_offering_model)

      expect {
        service_offering_model.reload
      }.to raise_error(Sequel::Error, 'Record not found')
    end

    context 'when the service offering has a service plan' do
      before do
        ServicePlan.make(service: service_offering_model)
      end

      it 'does not delete the service offering' do
        expect {
          subject.delete(service_offering_model)
        }.to raise_error(
          ServiceOfferingDelete::AssociationNotEmptyError,
          'Please delete the service_plans associations for your services.'
        )
      end
    end
  end
end
