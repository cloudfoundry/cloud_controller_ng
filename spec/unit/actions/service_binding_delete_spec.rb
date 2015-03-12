require 'spec_helper'
require 'actions/service_binding_delete'

module VCAP::CloudController
  describe ServiceBindingDelete do
    subject(:service_binding_delete) { ServiceBindingDelete.new(service_binding_dataset) }

    describe '#delete' do
      let!(:service_binding_1) { ServiceBinding.make }
      let!(:service_binding_2) { ServiceBinding.make }
      let!(:service_binding_dataset) { ServiceBinding.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        stub_unbind(service_binding_1)
        stub_unbind(service_binding_2)
      end

      it 'deletes all the bindings' do
        expect { service_binding_delete.delete }.to change { ServiceBinding.count }.by(-2)
      end
    end
  end
end
