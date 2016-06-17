require 'spec_helper'
require 'actions/services/service_binding_delete'

module VCAP::CloudController
  RSpec.describe ServiceBindingDelete do
    subject(:service_binding_delete) { ServiceBindingDelete.new }

    describe '#delete' do
      let!(:service_binding_1) { ServiceBinding.make }
      let(:service_instance) { service_binding_1.service_instance }
      let!(:service_binding_2) { ServiceBinding.make }
      let!(:service_binding_dataset) { ServiceBinding.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_unbind(service_binding_1)
        stub_unbind(service_binding_2)
      end

      it 'deletes the service bindings' do
        service_binding_delete.delete(service_binding_dataset)

        expect { service_binding_1.refresh }.to raise_error Sequel::Error, 'Record not found'
        expect { service_binding_2.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'fails if the instance has another operation in progress' do
        service_instance.service_instance_operation = ServiceInstanceOperation.make state: 'in progress'
        service_binding_delete = ServiceBindingDelete.new
        errors = service_binding_delete.delete([service_binding_1])
        expect(errors.first).to be_instance_of CloudController::Errors::ApiError
      end

      context 'when one binding deletion fails' do
        let(:service_binding_3) { ServiceBinding.make }

        before do
          stub_unbind(service_binding_1)
          stub_unbind(service_binding_2, status: 500)
          stub_unbind(service_binding_3)
        end

        it 'deletes all other bindings' do
          service_binding_delete.delete(service_binding_dataset)

          expect { service_binding_1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { service_binding_2.refresh }.not_to raise_error
          expect { service_binding_3.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'returns all of the errors caught' do
          errors = service_binding_delete.delete(service_binding_dataset)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end
      end
    end
  end
end
