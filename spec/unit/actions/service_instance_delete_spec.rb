require 'spec_helper'
require 'actions/service_instance_delete'

module VCAP::CloudController
  describe ServiceInstanceDelete do
    subject(:service_instance_delete) { ServiceInstanceDelete.new }

    describe '#delete' do
      let!(:service_instance_1) { ManagedServiceInstance.make }
      let!(:service_instance_2) { ManagedServiceInstance.make }

      let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      let!(:service_instance_dataset) { ServiceInstance.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        [service_instance_1, service_instance_2].each do |service_instance|
          stub_deprovision(service_instance)
          stub_unbind(service_instance.service_bindings.first)
        end
      end

      it 'deletes all the service_instances' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstance.count }.by(-2)
      end

      it 'deletes all the bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceBinding.count }.by(-2)
      end

      context 'when the broker returns an error for one of the deletions' do
        before do
          stub_deprovision(service_instance_2, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'returns errors it has captured' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(ServiceInstanceDeletionError)
        end
      end

      context 'when the broker returns an error for unbinding' do
        before do
          stub_unbind(service_instance_2.service_bindings.first, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'propagates service unbind errors' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(ServiceBindingDeletionError)
        end
      end
    end
  end
end
