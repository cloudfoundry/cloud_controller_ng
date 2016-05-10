require 'spec_helper'
require 'cloud_controller/diego/protocol/app_volume_mounts'

module VCAP::CloudController
  module Diego
    class Protocol
      describe AppVolumeMounts do
        let(:app) { App.make }
        let(:service_instance) { ServiceInstance.make(space: app.space) }
        let(:service_instance2) { ServiceInstance.make(space: app.space) }
        subject(:mounts) { AppVolumeMounts.new(app) }

        it 'is a flat array of all volume mounts in the app\'s service bindings' do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: [{ cool: 'binding' }, { uncool: 'bounding' }])
          ServiceBinding.make(app: app, service_instance: service_instance2, volume_mounts: [{ foo: 'bar' }, { baz: 'bot' }])

          expect(mounts.as_json).to match_array([
            { 'cool' => 'binding' },
            { 'uncool' => 'bounding' },
            { 'foo' => 'bar' },
            { 'baz' => 'bot' }
          ])
        end

        it 'does not include empty entries for service bindings with no volume mounts' do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: [{ cool: 'binding' }, { uncool: 'bounding' }])
          ServiceBinding.make(app: app, service_instance: service_instance2)

          expect(mounts.as_json).to match_array([
            { 'cool' => 'binding' },
            { 'uncool' => 'bounding' }
          ])
        end
      end
    end
  end
end
