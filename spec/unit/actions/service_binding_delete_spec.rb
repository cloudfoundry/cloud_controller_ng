require 'spec_helper'
require 'actions/service_binding_delete'

module VCAP::CloudController
  describe ServiceBindingModelDelete do
    subject(:service_binding_delete) { described_class.new }

    describe '#synchronous_delete' do
      let(:service_binding) { ServiceBindingModel.make }

      before do
        allow(service_binding.client).to receive(:unbind)
      end

      it 'deletes the service binding' do
        service_binding_delete.synchronous_delete(service_binding)
        expect(service_binding.exists?).to be_falsey
      end

      it 'asks the broker to unbind the instance' do
        service_binding_delete.synchronous_delete(service_binding)
        expect(service_binding.client).to have_received(:unbind).with(service_binding)
      end

      context 'when the service instance has another operation in progress' do
        before do
          service_binding.service_instance.service_instance_operation = ServiceInstanceOperation.make(state: 'in progress')
        end

        it 'raises an error' do
          expect {
            service_binding_delete.synchronous_delete(service_binding)
          }.to raise_error(ServiceBindingModelDelete::FailedToDelete, /operation in progress/)
        end
      end

      context 'when the service broker client raises an error' do
        before do
          allow(service_binding.client).to receive(:unbind).and_raise(StandardError.new('kablooey'))
        end

        it 'raises an error' do
          expect {
            service_binding_delete.synchronous_delete(service_binding)
          }.to raise_error(ServiceBindingModelDelete::FailedToDelete, /kablooey/)
        end
      end
    end
  end
end
