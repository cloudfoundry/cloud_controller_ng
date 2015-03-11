require 'spec_helper'
require 'actions/service_instance_delete'

module VCAP::CloudController
  describe ServiceInstanceDelete do
    subject(:service_instance_delete) { ServiceInstanceDelete.new(service_instance_dataset) }

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
          attrs = service_instance.client.attrs
          uri = URI(attrs[:url])
          uri.user = attrs[:auth_username]
          uri.password = attrs[:auth_password]

          plan = service_instance.service_plan
          service = plan.service

          uri = uri.to_s
          uri += "/v2/service_instances/#{service_instance.guid}"
          stub_request(:delete, uri + "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}").to_return(status: 200, body: '{}')

          service_binding = service_instance.service_bindings.first
          uri += "/service_bindings/#{service_binding.guid}"
          stub_request(:delete, uri + "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}").to_return(status: 200, body: '{}')
        end
      end

      it 'deletes all the service_instances' do
        expect { service_instance_delete.delete }.to change { ServiceInstance.count }.by(-2)
      end

      it 'deletes all the bindings for all the service instance' do
        expect { service_instance_delete.delete }.to change { ServiceBinding.count }.by(-2)
      end
    end
  end
end
