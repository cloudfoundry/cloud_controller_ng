require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'async bindings' do
    include VCAP::CloudController::BrokerApiHelper

    context 'when the service broker can only perform async operations' do
      before do
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'true' })).
          to_return(status: 202, body: '{}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'false' })).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          with(query: hash_excluding('accepts_incomplete')).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')

        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'true' })).
          to_return(status: 202, body: '{}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'false' })).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          with(query: hash_excluding('accepts_incomplete')).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
      end

      context 'when a service instance is shared' do
        let(:service_instance) { ManagedServiceInstance.make }
        let(:target_space) { Space.make }

        before do
          service_instance.add_shared_space(target_space)
        end

        context 'when there are bindings in the target space' do
          let(:target_app) { AppModel.make(space: target_space) }
          let!(:target_binding) { ServiceBinding.make(app: target_app, service_instance: service_instance) }

          it 'can unbind if the service instance is deleted recursively' do
            delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

            expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made.times(2)
            expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made
          end

          context 'where there are bindings in the source space' do
            let(:source_space) { service_instance.space }
            let(:source_app) { AppModel.make(space: source_space) }
            let!(:source_binding) { ServiceBinding.make(app: source_app, service_instance: service_instance) }

            it 'can unbind if the service instance is deleted recursively' do
              delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

              expect(a_request(:delete, unbind_url(source_binding)).with(query: { accepts_incomplete: true })).to have_been_made.once
              expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made.times(2)
              expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made
            end
          end
        end
      end
    end
  end
end

