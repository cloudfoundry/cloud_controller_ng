require 'spec_helper'
require 'actions/service_binding_create'

module VCAP::CloudController
  describe ServiceBindingCreate do
    let(:service_instance) { ManagedServiceInstance.make }

    context 'when the database fails to save the binding' do
      before do
        allow_any_instance_of(ServiceBinding).to receive(:save).and_raise
      end

      context 'when the unbind fails' do
        before do
          stub_bind(service_instance)
          stub_request(:delete, %r{/v2/service_instances/#{service_instance.guid}/service_bindings/}).
              to_return(status: 500, body: {}.to_json)
        end

        it 'logs that the unbind failed' do
          logger_double = double
          allow(logger_double).to receive :error

          binding_attrs = {
              'service_instance_guid' => service_instance.guid,
          }

          ServiceBindingCreate.new(logger_double).bind(service_instance, binding_attrs, {})

          expect(logger_double).to have_received(:error).with /Unable to unbind/
        end
      end
    end
  end
end
