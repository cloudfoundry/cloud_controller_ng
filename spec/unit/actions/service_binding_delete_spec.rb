require 'spec_helper'
require 'actions/service_binding_delete'

module VCAP::CloudController
  describe ServiceBindingDelete do
    subject(:service_binding_delete) { ServiceBindingDelete.new }

    describe '#delete' do
      let!(:service_binding_1) { ServiceBinding.make }
      let!(:service_binding_2) { ServiceBinding.make }
      let!(:service_binding_dataset) { ServiceBinding.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        [service_binding_1, service_binding_2].each do |service_binding|
          attrs = service_binding.client.attrs
          uri = URI(attrs[:url])
          uri.user = attrs[:auth_username]
          uri.password = attrs[:auth_password]

          service_instance = service_binding.service_instance
          plan = service_instance.service_plan
          service = plan.service

          uri = uri.to_s
          uri += "/v2/service_instances/#{service_instance.guid}"
          uri += "/service_bindings/#{service_binding.guid}"
          uri += "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"

          stub_request(:delete, uri).to_return(status: 200, body: '{}')
        end
      end

      it 'deletes all the bindings' do
        expect { service_binding_delete.delete(service_binding_dataset) }.to change { ServiceBinding.count }.by(-2)
      end
    end
  end
end
