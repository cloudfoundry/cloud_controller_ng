require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'async bindings' do
    include VCAP::CloudController::BrokerApiHelper

    context 'when the service broker can only perform async operations' do
      before do
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'false' })).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'true' })).
          to_return(status: 202, body: '{}')

        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'false' })).
          to_return(status: 422, body: '{"error": "AsyncRequired"}')
        stub_request(:delete, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+}).
          with(query: hash_including({ 'accepts_incomplete' => 'true' })).
          to_return(status: 202, body: '{}')
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

          it 'can unbind if the service instance is deleted recursively and accepts_incomplete is true' do
            delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

            expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, deprovision_url(service_instance)).with(query: { accepts_incomplete: true })).not_to have_been_made

            expect(last_response).to have_status_code(502)
            body = JSON.parse(last_response.body)
            expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
            expect(body['description']).to eq async_unbind_in_progress_error(service_instance.name, target_app.name)
          end

          it 'can unbind if the service instance is deleted recursively and accepts_incomplete is not set' do
            delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true', admin_headers)

            expect(a_request(:delete, unbind_url(target_binding))).to have_been_made
            expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made

            expect(last_response).to have_status_code(502)
            body = JSON.parse(last_response.body)
            expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
            expect(body['description']).to eq async_unbind_not_supported_error(service_instance.name)
          end

          context 'and when there are bindings in the source space' do
            let(:source_space) { service_instance.space }
            let(:source_app) { AppModel.make(space: source_space) }
            let!(:source_binding) { ServiceBinding.make(app: source_app, service_instance: service_instance) }

            it 'can unbind if the service instance is deleted recursively and accepts_incomplete is true' do
              delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

              expect(a_request(:delete, unbind_url(source_binding)).with(query: { accepts_incomplete: true })).to have_been_made
              expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made
              expect(a_request(:delete, deprovision_url(service_instance)).with(query: { accepts_incomplete: true })).not_to have_been_made

              expect(last_response).to have_status_code(502)
              body = JSON.parse(last_response.body)
              expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
              expect(body['description']).to match multiple_async_unbind_in_progress_error(service_instance.name, source_app.name, target_app.name)
            end

            it 'can unbind if the service instance is deleted recursively' do
              delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true', admin_headers)

              expect(a_request(:delete, unbind_url(source_binding))).to have_been_made
              expect(a_request(:delete, unbind_url(target_binding))).to have_been_made
              expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made

              expect(last_response).to have_status_code(502)
              body = JSON.parse(last_response.body)
              expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
              expect(body['description']).to eq multiple_async_unbind_not_supported_error(service_instance.name)
            end
          end
        end
      end
    end

    context 'when the broker returns 410 on last_operation during binding creation' do
      before do
        setup_cc
        setup_broker(default_catalog(bindings_retrievable: true))
        provision_service
        create_app

        stub_async_binding_last_operation(body: {}, return_code: 410)
      end

      it 'should continue polling' do
        async_bind_service(status: 202)

        expect(last_response).to have_status_code(202)
        body = JSON.parse(last_response.body)
        expect(body['entity']['last_operation']['state']).to eq('in progress')

        Delayed::Worker.new.work_off

        service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_id)
        expect(a_request(:get,
                         "#{service_binding_url(service_binding)}/last_operation?plan_id=plan1-guid-here&service_id=service-guid-here"
                        )).to have_been_made

        Timecop.travel(Time.now + 1.minute)
        Delayed::Worker.new.work_off

        expect(a_request(:get,
                         "#{service_binding_url(service_binding)}/last_operation?plan_id=plan1-guid-here&service_id=service-guid-here"
                        )).to have_been_made.twice
      end
    end
  end

  def async_unbind_in_progress_error(instance_name, app_name)
    "Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted.\n\n" \
      "\tAn operation for the service binding between app #{app_name} and service instance #{instance_name} is in progress."
  end

  def multiple_async_unbind_in_progress_error(instance_name, *apps_name)
    "^Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted.\n\n" \
      "\tAn operation for the service binding between app .+ and service instance #{instance_name} is in progress.\n\n" \
      "\tAn operation for the service binding between app .+ and service instance #{instance_name} is in progress.$"
  end

  def async_unbind_not_supported_error(instance_name)
    "Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted.\n\n" \
      "\tService broker failed to delete service binding for instance #{instance_name}: This service plan requires client support for asynchronous service operations."
  end

  def multiple_async_unbind_not_supported_error(instance_name)
    "Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted.\n\n" \
      "\tService broker failed to delete service binding for instance #{instance_name}: This service plan requires client support for asynchronous service operations.\n\n" \
      "\tService broker failed to delete service binding for instance #{instance_name}: This service plan requires client support for asynchronous service operations."
  end
end
