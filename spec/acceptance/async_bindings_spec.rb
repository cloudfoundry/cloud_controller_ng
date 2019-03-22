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
        stub_request(:get, %r{/v2/service_instances/[[:alnum:]-]+/service_bindings/[[:alnum:]-]+/last_operation}).
          with(query: hash_including(:plan_id, :service_id)).
          to_return(status: 200, body: '{"state": "in progress"}')

        stub_request(:delete, %r{/v3/apps/[[:alnum:]-]+}).
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

          it 'issues an unbind and fails the instance deletion if the service instance is deleted recursively and accepts_incomplete is true' do
            delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

            expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, deprovision_url(service_instance)).with(query: { accepts_incomplete: true })).not_to have_been_made

            expect(last_response).to have_status_code(502)
            body = JSON.parse(last_response.body)
            expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
            expect(body['description']).to eq async_unbind_in_progress_error(service_instance.name, target_app.name)
          end

          it 'fails to unbind if the service instance is deleted recursively and accepts_incomplete is not set' do
            delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true', admin_headers)

            expect(a_request(:delete, unbind_url(target_binding))).to have_been_made
            expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made

            expect(last_response).to have_status_code(502)
            body = JSON.parse(last_response.body)
            expect(body['error_code']).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
            expect(body['description']).to eq async_unbind_not_supported_error(service_instance.name, target_app.name)
          end

          context 'and when there are bindings in the source space' do
            let(:source_space) { service_instance.space }
            let(:source_app) { AppModel.make(space: source_space) }
            let!(:source_binding) { ServiceBinding.make(app: source_app, service_instance: service_instance) }

            it 'issues unbinds and fails the instance deletion if the service instance is deleted recursively and accepts_incomplete is true' do
              delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true&accepts_incomplete=true', admin_headers)

              expect(last_response).to have_status_code(502)

              expect(a_request(:delete, unbind_url(source_binding)).with(query: { accepts_incomplete: true })).to have_been_made
              expect(a_request(:delete, unbind_url(target_binding)).with(query: { accepts_incomplete: true })).to have_been_made
              expect(a_request(:delete, deprovision_url(service_instance)).with(query: { accepts_incomplete: true })).not_to have_been_made

              body = JSON.parse(last_response.body)
              err_code = body['error_code']
              err_msg = body['description']

              expect(err_code).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
              expect(err_msg).to match "^Deletion of service instance #{service_instance.name} failed because one or more associated resources could not be deleted.$"
              expect(err_msg).to match "^\tAn operation for the service binding between app #{source_app.name} and service instance #{service_instance.name} is in progress.$"
              expect(err_msg).to match "^\tAn operation for the service binding between app #{target_app.name} and service instance #{service_instance.name} is in progress.$"

              expect(err_msg.split("\t")).to have(3).items
            end

            it 'fails to unbind if the service instance is deleted recursively' do
              delete("/v2/service_instances/#{service_instance.guid}", 'recursive=true', admin_headers)

              expect(last_response).to have_status_code(502)

              expect(a_request(:delete, unbind_url(source_binding))).to have_been_made
              expect(a_request(:delete, unbind_url(target_binding))).to have_been_made
              expect(a_request(:delete, deprovision_url(service_instance))).not_to have_been_made

              body = JSON.parse(last_response.body)
              err_code = body['error_code']
              err_msg = body['description']
              expect(err_code).to eq 'CF-ServiceInstanceRecursiveDeleteFailed'
              expect(err_msg).to match "^Deletion of service instance #{service_instance.name} failed because one or more associated resources could not be deleted.$"
              expect(err_msg).to match "^\tAn unbind operation for the service binding between app #{target_app.name} and service instance #{service_instance.name} failed: " \
                'This service plan requires client support for asynchronous service operations.$'
              expect(err_msg).to match "^\tAn unbind operation for the service binding between app #{source_app.name} and service instance #{service_instance.name} failed: " \
                'This service plan requires client support for asynchronous service operations.$'

              expect(err_msg.split("\t")).to have(3).items
            end
          end
        end
      end

      context 'when DELETE /v3/apps/:guid is called' do
        context 'and multiple service bindings exist' do
          let(:space) { Space.make }
          let(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
          let(:package) { VCAP::CloudController::PackageModel.make(app: app_model) }
          let!(:droplet) { VCAP::CloudController::DropletModel.make(package: package, app: app_model) }
          let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }
          let!(:deployment) { VCAP::CloudController::DeploymentModel.make(app: app_model) }

          let!(:service_binding1) { ServiceBinding.make(app: app_model, service_instance: ManagedServiceInstance.make(space: space)) }
          let!(:service_binding2) { ServiceBinding.make(app: app_model, service_instance: ManagedServiceInstance.make(space: space)) }

          it 'returns a list of errors for the service bindings' do
            delete("/v3/apps/#{app_model.guid}", nil, admin_headers)
            expect(last_response).to have_status_code(202)

            Delayed::Worker.new.work_off

            expect(a_request(:delete, unbind_url(service_binding1)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, unbind_url(service_binding2)).with(query: { accepts_incomplete: true })).to have_been_made

            get(last_response.headers['Location'], nil, admin_headers)
            expect(last_response).to have_status_code(200)
            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['state']).to eq('FAILED')
            expect(parsed_response['errors'].count).to eq(2)
            expect(parsed_response['errors'][0]['title']).to eq('CF-UnprocessableEntity')
            expect(parsed_response['errors'][0]['detail']).to match('An operation for the service binding .* is in progress')
            expect(parsed_response['errors'][1]['title']).to eq('CF-UnprocessableEntity')
            expect(parsed_response['errors'][1]['detail']).to match('An operation for the service binding .* is in progress')
          end
        end
      end

      context 'when DELETE /v2/apps/:guid is called' do
        context 'and multiple service bindings exist' do
          let(:process) { ProcessModelFactory.make }

          let!(:service_binding1) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }
          let!(:service_binding2) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }

          it 'returns a concatenated error for the service bindings' do
            delete("/v2/apps/#{process.app.guid}", 'recursive=true', admin_headers)
            expect(last_response).to have_status_code(502)

            expect(a_request(:delete, unbind_url(service_binding1)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, unbind_url(service_binding2)).with(query: { accepts_incomplete: true })).to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-AppRecursiveDeleteFailed')
            expect(parsed_response['description']).to match(
              /An operation for the service binding .* is in progress.*An operation for the service binding .* is in progress/m
            )
          end
        end
      end

      context 'when DELETE /v2/spaces/:guid is called' do
        context 'and multiple service bindings exist' do
          let(:process) { ProcessModelFactory.make }

          let!(:service_binding1) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }
          let!(:service_binding2) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }

          it 'returns a concatenated error for the service bindings' do
            delete("/v2/spaces/#{process.space.guid}", 'recursive=true', admin_headers)
            expect(last_response).to have_status_code(502)

            expect(a_request(:delete, unbind_url(service_binding1)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, unbind_url(service_binding2)).with(query: { accepts_incomplete: true })).to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-SpaceDeletionFailed')
            expect(parsed_response['description']).to match(
              /An operation for the service binding .* is in progress.*An operation for the service binding .* is in progress/m
            )
          end
        end
      end

      context 'when DELETE /v2/organizations/:guid is called' do
        context 'and multiple service bindings exist' do
          let(:process) { ProcessModelFactory.make }

          let!(:service_binding1) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }
          let!(:service_binding2) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }

          it 'returns a concatenated error for the service bindings' do
            delete("/v2/organizations/#{process.organization.guid}", 'recursive=true', admin_headers)
            expect(last_response).to have_status_code(502)

            expect(a_request(:delete, unbind_url(service_binding1)).with(query: { accepts_incomplete: true })).to have_been_made
            expect(a_request(:delete, unbind_url(service_binding2)).with(query: { accepts_incomplete: true })).to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-OrganizationDeletionFailed')
            expect(parsed_response['description']).to match(
              /An operation for the service binding .* is in progress.*An operation for the service binding .* is in progress/m
            )
          end
        end
      end

      context 'when PUT /v2/service_instances/:guid is called and when an async binding operation is in progress' do
        let(:process) { ProcessModelFactory.make }
        let(:service_binding) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }
        let!(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress', type: operation_type, service_binding_id: service_binding.id) }

        let(:body) do
          {
            parameters: { key: 'value' }
          }.to_json
        end

        context 'when the binding operation is create' do
          let(:operation_type) { 'create' }

          it 'returns an operation in progress error' do
            put("/v2/service_instances/#{service_binding.service_instance.guid}?accepts_incomplete=true", body, admin_headers)
            expect(last_response).to have_status_code(409)

            expect(a_request(:update, update_url(service_binding.service_instance))).not_to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-AsyncServiceBindingOperationInProgress')
            expect(parsed_response['description']).to(
              match(/An operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} is in progress./))
          end
        end

        context 'when the binding operation is delete' do
          let(:operation_type) { 'delete' }

          it 'returns an operation in progress error' do
            put("/v2/service_instances/#{service_binding.service_instance.guid}?accepts_incomplete=true", body, admin_headers)
            expect(last_response).to have_status_code(409)

            expect(a_request(:update, update_url(service_binding.service_instance))).not_to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-AsyncServiceBindingOperationInProgress')
            expect(parsed_response['description']).to(
              match(/An operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} is in progress./))
          end
        end
      end

      context 'when DELETE /v2/service_instances/:guid is called and when an async binding operation is in progress' do
        let(:process) { ProcessModelFactory.make }
        let(:service_binding) { ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space)) }
        let!(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress', type: operation_type, service_binding_id: service_binding.id) }

        context 'when the binding operation is create' do
          let(:operation_type) { 'create' }

          it 'returns an operation in progress error' do
            delete("/v2/service_instances/#{service_binding.service_instance.guid}?accepts_incomplete=true&recursive=true", {}, admin_headers)
            expect(last_response).to have_status_code(502)

            expect(a_request(:delete, deprovision_url(service_binding.service_instance))).not_to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-ServiceInstanceRecursiveDeleteFailed')
            expect(parsed_response['description']).to(
              match(/An operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} is in progress./))
          end
        end

        context 'when the binding operation is delete' do
          let(:operation_type) { 'delete' }

          it 'returns an operation in progress error' do
            delete("/v2/service_instances/#{service_binding.service_instance.guid}?accepts_incomplete=true&recursive=true", {}, admin_headers)
            expect(last_response).to have_status_code(502)

            expect(a_request(:delete, deprovision_url(service_binding.service_instance))).not_to have_been_made

            parsed_response = JSON.parse(last_response.body)
            expect(parsed_response['error_code']).to eq('CF-ServiceInstanceRecursiveDeleteFailed')
            expect(parsed_response['description']).to match(/An operation for the service binding .* is in progress./)
          end
        end
      end
    end

    context 'when the broker returns 410 on last_operation during binding creation' do
      let(:url) { "http://#{stubbed_broker_host}/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+/last_operation" }

      before do
        setup_cc
        setup_broker(default_catalog(bindings_retrievable: true))
        provision_service
        create_app

        stub_async_last_operation(body: {}, return_code: 410, url: url)
      end

      it 'should continue polling in a new background job' do
        async_bind_service(status: 202)

        expect(last_response).to have_status_code(202)
        body = JSON.parse(last_response.body)
        expect(body['entity']['last_operation']['state']).to eq('in progress')

        Delayed::Worker.new.work_off

        service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
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

  def async_unbind_not_supported_error(instance_name, app_name)
    "Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted.\n\n" \
      "\tAn unbind operation for the service binding between app #{app_name} and service instance #{instance_name} failed: " \
      'This service plan requires client support for asynchronous service operations.'
  end
end
