require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.15' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    describe 'updates service instances based on the plan object of the catalog' do
      context 'when the broker supports plan_updateable on plan level' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:plans].first[:plan_updateable] = true
          catalog
        end

        before do
          setup_broker(catalog)
        end

        it 'successfully updates the service instance plan' do
          provision_service
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @plan_guid

          update_service_instance(200)
          expect(last_response).to have_status_code(201)
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @large_plan_guid
        end
      end
    end

    describe 'platform delays polling to last_operation based on Retry-After header' do
      let(:default_poll_interval) { VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds) }
      let(:retry_after_interval) { default_poll_interval * 4 }

      before do
        setup_broker(default_catalog(plan_updateable: true, bindings_retrievable: true))
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        stub_async_last_operation(body: { state: 'in progress' }, headers: { 'Retry-After': retry_after_interval })
      end

      describe 'service instances' do
        context 'when provisioning a service instance' do
          it 'should poll the broker at the given retry interval' do
            expect(async_provision_service).to have_status_code(202)

            expect(
              a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
            ).to have_been_made

            service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

            assert_cc_polls_service_instance_last_operation(
              service_instance,
              default_poll_interval,
              retry_after_interval
            )
          end
        end

        context 'when deprovisioning a service instance' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_delete_service).to have_status_code(202)

            expect(
              a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
            ).to have_been_made

            assert_cc_polls_service_instance_last_operation(
              service_instance,
              default_poll_interval,
              retry_after_interval
            )
          end
        end

        context 'when updating a service instance' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_update_service).to have_status_code(202)

            expect(
              a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

            assert_cc_polls_service_instance_last_operation(
              service_instance,
              default_poll_interval,
              retry_after_interval
            )
          end
        end
      end

      describe 'service bindings' do
        context 'when creating a service binding' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
            create_app
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_bind_service(status: 202)).to have_status_code(202)

            expect(
              a_request(:put, bind_url(service_instance, accepts_incomplete: true))).to have_been_made

            assert_cc_polls_service_binding_last_operation(
              service_instance,
              default_poll_interval,
              retry_after_interval
            )
          end
        end

        context 'when removing a service binding' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
            create_app
            bind_service
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_unbind_service(status: 202)).to have_status_code(202)

            service_binding = VCAP::CloudController::ServiceBinding.last

            expect(
              a_request(:delete, unbind_url(service_binding, accepts_incomplete: true))).to have_been_made

            assert_cc_polls_service_binding_last_operation(
              service_instance,
              default_poll_interval,
              retry_after_interval
            )
          end
        end
      end
    end

    describe 'platform limits polling duration to last_operation based on plan maximum_polling_duration value' do
      let(:default_max_poll_duration) { VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes) }
      let(:broker_max_poll_duration_in_seconds) { 60 }

      before do
        setup_broker(default_catalog(maximum_polling_duration: broker_max_poll_duration_in_seconds, plan_updateable: true, bindings_retrievable: true))
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        stub_async_last_operation(body: { state: 'in progress' })
      end

      describe 'service instances' do
        context 'when creating a service instance' do
          it 'should stop polling the broker after the given maximum_polling_duration' do
            expect(async_provision_service).to have_status_code(202)

            expect(
              a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
            ).to have_been_made

            service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

            last_operation_url = %r{#{service_instance_url(service_instance)}/last_operation}
            assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration_in_seconds, default_max_poll_duration)
          end
        end

        context 'when updating a service instance' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
          end

          it 'should stop polling the broker after the given maximum_polling_duration' do
            expect(async_update_service).to have_status_code(202)

            expect(a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

            service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

            last_operation_url = %r{#{service_instance_url(service_instance)}/last_operation}
            assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration_in_seconds, default_max_poll_duration)
          end
        end

        context 'when deleting a service instance' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
          end

          it 'should stop polling the broker after the given maximum_polling_duration' do
            expect(async_delete_service).to have_status_code(202)

            expect(a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))).to have_been_made

            service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

            last_operation_url = %r{#{service_instance_url(service_instance)}/last_operation}
            assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration_in_seconds, default_max_poll_duration)
          end
        end
      end

      describe 'service bindings' do
        context 'when creating a service binding' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
            create_app
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_bind_service(status: 202)).to have_status_code(202)

            expect(a_request(:put, bind_url(service_instance, accepts_incomplete: true))).to have_been_made

            last_operation_url = %r{#{bind_url(service_instance)}/last_operation}
            assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration_in_seconds, default_max_poll_duration)
          end
        end

        context 'when removing a service binding' do
          let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

          before do
            @service_instance_guid = service_instance.guid
            create_app
            bind_service
          end

          it 'should poll the broker at the given retry interval' do
            expect(async_unbind_service(status: 202)).to have_status_code(202)

            service_binding = VCAP::CloudController::ServiceBinding.last

            expect(a_request(:delete, unbind_url(service_binding, accepts_incomplete: true))).to have_been_made
            last_operation_url = %r{#{service_binding_url(service_binding)}/last_operation}
            assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration_in_seconds, default_max_poll_duration)
          end
        end
      end
    end

    context 'service instance context hash' do
      let(:catalog) { default_catalog(plan_updateable: true) }
      before do
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        provision_service(name: 'instance-007')
      end

      context 'service provision request' do
        it 'receives the correct attributes in the context' do
          expected_context_attributes = {
            'platform' => 'cloudfoundry',
            'organization_guid' => @org_guid,
            'space_guid' => @space_guid,
            'instance_name' => 'instance-007',
            'organization_name' => @space.organization.name,
            'space_name' => @space.name
          }

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'service update request' do
        before do
          update_service_instance(200)
        end

        it 'receives the correct attributes in the context' do
          expected_context_attributes = {
            'platform' => 'cloudfoundry',
            'organization_guid' => @org_guid,
            'space_guid' => @space_guid,
            'instance_name' => 'instance-007',
            'organization_name' => @space.organization.name,
            'space_name' => @space.name
          }

          expect(
            a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'service rename request' do
        before do
          rename_service_instance(200, { name: 'instance-014' })
        end

        context 'when broker has allow_context_updates enabled in catalog' do
          let(:catalog) { default_catalog(allow_context_updates: true) }

          it 'receives the correct attributes in the context' do
            expected_context_attributes = {
              'platform' => 'cloudfoundry',
              'organization_guid' => @org_guid,
              'space_guid' => @space_guid,
              'instance_name' => 'instance-014',
              'organization_name' => @space.organization.name,
              'space_name' => @space.name
            }

            expect(
              a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with { |req|
                context = JSON.parse(req.body)['context']
                context >= expected_context_attributes
              }).to have_been_made
          end
        end

        context 'when broker has allow_context_updates disabled in catalog' do
          let(:catalog) { default_catalog(allow_context_updates: false) }

          it 'does not receive a patch update request' do
            expect(
              a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}})
            ).not_to have_been_made
          end
        end
      end
    end

    context 'service bindings context hash' do
      let(:catalog) { default_catalog(requires: ['route_forwarding']) }
      let(:expected_context_attributes) { {
        'platform' => 'cloudfoundry',
        'organization_guid' => @org_guid,
        'space_guid' => @space_guid,
        'organization_name' => @space.organization.name,
        'space_name' => @space.name
      }
      }

      before do
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        provision_service(name: 'instance-007')
      end

      context 'for binding to an application' do
        before do
          create_app
          bind_service
        end

        it 'receives the correct attributes in the context' do
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'for create service key' do
        before do
          create_service_key
        end

        it 'receives the correct attributes in the context' do
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end

      context 'for bind route service' do
        let(:route) { VCAP::CloudController::Route.make(space: @space) }
        before do
          create_route_binding(route)
        end

        it 'receives the correct attributes in the context' do
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_guid}}).with { |req|
              context = JSON.parse(req.body)['context']
              context >= expected_context_attributes
            }).to have_been_made
        end
      end
    end

    describe 'cancel service instance create async operation' do
      before do
        setup_broker(default_catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      context 'when provisioning a service instance' do
        it 'delete request should cancel the creation and delete the instance synchronously' do
          async_provision_service
          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          expect(delete_service).to have_status_code(204)

          expect(
            a_request(:delete, deprovision_url(service_instance))
          ).to have_been_made

          expect(VCAP::CloudController::Event.order(:id).all.map(&:type)).to end_with(
            'audit.service_instance.start_create',
            'audit.service_instance.delete'
          )

          expect { service_instance.reload }.to raise_error(Sequel::Error)
        end

        it 'should not delete the instance if the broker rejects the request' do
          async_provision_service
          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          expect(delete_service(status: 422, broker_response_body: %({"error": "ConcurrencyError"}))).to have_status_code(409)

          expect { service_instance.reload }.not_to raise_error
        end

        it 'delete request should cancel the creation and delete the instance asynchronously' do
          async_provision_service
          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          expect(async_delete_service).to have_status_code(202)
          expect(
            a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
          ).to have_been_made
          expect { service_instance.reload }.not_to raise_error

          Timecop.freeze(Time.now) do
            stub_async_last_operation
            Delayed::Worker.new.work_off
            expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made
          end

          expect(VCAP::CloudController::Event.order(:id).all.map(&:type)).to end_with(
            'audit.service_instance.start_create',
            'audit.service_instance.start_delete',
            'audit.service_instance.delete'
          )

          expect { service_instance.reload }.to raise_error(Sequel::Error)
        end
      end
    end

    context 'when the broker provides maintenance_info' do
      let(:catalog) do
        catalog = default_catalog
        catalog[:services].first[:plans].first[:maintenance_info] = { 'version' => '2.0.0', 'description' => 'Test description' }
        catalog
      end

      before do
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      it 'is saved with the service plan' do
        get("/v2/service_plans/#{@plan_guid}",
            {}.to_json,
            json_headers(admin_headers))

        parsed_body = MultiJson.load(last_response.body)
        maintenance_info = parsed_body['entity']['maintenance_info']
        expect(maintenance_info).to eq({ 'version' => '2.0.0', 'description' => 'Test description' })
      end

      context 'when updating the service with the provided maintenance_info' do
        let(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            space_guid: @space_guid,
            service_plan_guid: @plan_guid,
            maintenance_info: { 'version' => '1.0.0' })
        end

        before do
          @service_instance_guid = service_instance.guid
        end

        it 'should forward the maintanance info to the broker (only version)' do
          response = async_update_service(maintenance_info: { 'version' => '2.0.0', 'description' => 'Test description' })
          expect(response).to have_status_code(202)
          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true)).with do |req|
              expect(JSON.parse(req.body)).to include('maintenance_info' => { 'version' => '2.0.0' })
            end
          ).to have_been_made
        end
      end
    end

    describe 'cancel service binding create async operation' do
      before do
        setup_broker(default_catalog(bindings_retrievable: true))
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        provision_service
      end

      context 'when binding is in progress' do
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid) }

        before do
          create_app
          async_bind_service
          expect(a_request(:put, bind_url(service_instance, accepts_incomplete: true))).to have_been_made
        end

        context 'broker responds synchronously to the unbind request' do
          it 'deletes the binding' do
            service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
            expect(unbind_service).to have_status_code(204)

            expect(a_request(:delete, unbind_url(service_binding))).to have_been_made

            expect(VCAP::CloudController::Event.order(:id).all.map(&:type)).to end_with(
              'audit.service_binding.start_create',
              'audit.service_binding.delete'
            )

            expect { service_binding.reload }.to raise_error(Sequel::Error)
          end
        end

        context 'broker rejects the unbind request' do
          it 'raise concurrency error' do
            service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
            expect(unbind_service(status: 422, response_body: { error: 'ConcurrencyError' })).to have_status_code(409)

            expect(a_request(:delete, unbind_url(service_binding))).to have_been_made

            expect(VCAP::CloudController::Event.order(:id).all.map(&:type)).to end_with(
              'audit.service_binding.start_create',
            )

            expect(service_binding.reload).not_to be_nil
          end
        end

        it 'unbind request should cancel the bind and delete the binding asynchronously' do
          stub_async_last_operation
          service_binding = VCAP::CloudController::ServiceBinding.find(guid: @binding_guid)
          expect(async_unbind_service).to have_status_code(202)

          expect(a_request(:delete, unbind_url(service_binding, accepts_incomplete: true))).to have_been_made

          expect(service_binding.reload).not_to be_nil

          Timecop.freeze(Time.now) do
            Delayed::Worker.new.work_off
            expect(a_request(:get, %r{#{service_binding_url(service_binding)}/last_operation})).to have_been_made
          end

          expect(VCAP::CloudController::Event.order(:id).all.map(&:type)).to end_with(
            'audit.service_binding.start_create',
            'audit.service_binding.start_delete',
            'audit.service_binding.delete'
          )
          expect { service_binding.reload }.to raise_error(Sequel::Error)
        end
      end
    end
  end
end

def assert_cc_polls_last_operation_with_provided_max_duration(last_operation_url, broker_max_poll_duration, default_max_poll_duration)
  Timecop.freeze(Time.now) do
    Delayed::Worker.new.work_off
    expect(a_request(:get, last_operation_url)).to have_been_made

    # between the broker max. poll duration and the platform max. poll duration
    # we expect no further requests to last_operation to have been made
    Timecop.travel(broker_max_poll_duration.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, last_operation_url)).to have_been_made
    WebMock.reset_executed_requests!

    Timecop.travel(default_max_poll_duration.minutes)
    Delayed::Worker.new.work_off
    expect(a_request(:get, last_operation_url)).not_to have_been_made
  end
end

def assert_cc_polls_service_instance_last_operation(service_instance, default_poll_interval, retry_after_interval)
  Timecop.freeze(Time.now) do
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made

    Timecop.travel(default_poll_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.once

    Timecop.travel(retry_after_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.twice
  end
end

def assert_cc_polls_service_binding_last_operation(service_instance, default_poll_interval, retry_after_interval)
  Timecop.freeze(Time.now) do
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{bind_url(service_instance)}/last_operation})).to have_been_made

    Timecop.travel(default_poll_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{bind_url(service_instance)}/last_operation})).to have_been_made.once

    Timecop.travel(retry_after_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{bind_url(service_instance)}/last_operation})).to have_been_made.twice
  end
end
