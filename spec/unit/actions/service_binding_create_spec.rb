require 'spec_helper'
require 'actions/service_binding_create'

module VCAP::CloudController
  RSpec.describe ServiceBindingCreate do
    describe '#create' do
      subject(:service_binding_create) { ServiceBindingCreate.new(user_guid, user_email) }
      let(:user_guid) { 'some-guid' }
      let(:user_email) { 'are@youreddy.com' }
      let(:volume_mount_services_enabled) { true }

      let(:app_model) { AppModel.make }
      let(:service_instance) { ManagedServiceInstance.make(space_guid: app_model.space.guid) }
      let(:request) do
        {
          'type'          => 'app',
          'relationships' => {
            'app' => {
              'guid' => app_model.guid
            },
            'service_instance' => {
              'guid' => service_instance.guid
            },
            'data' => { 'parameters' => arbitrary_parameters }
          },
        }
      end
      let(:message) { ServiceBindingCreateMessage.create_from_http_request(request) }
      let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }
      let(:logger) { instance_double(Steno::Logger) }
      let(:arbitrary_parameters) { {} }

      before do
        credentials          = { 'credentials' => '{}' }.to_json
        fake_service_binding = ServiceBindingModel.new(service_instance: service_instance, guid: '')
        opts                 = {
          fake_service_binding: fake_service_binding,
          body:                 credentials
        }
        stub_bind(service_instance, opts)
      end

      it 'creates a v3 Service Binding' do
        service_binding = service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)

        expect(ServiceBindingModel.count).to eq(1)
        expect(service_binding.app_guid).to eq(app_model.guid)
        expect(service_binding.service_instance_guid).to eq(service_instance.guid)
        expect(service_binding.type).to eq('app')
      end

      it 'creates an audit.service_binding.create event' do
        service_binding = service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)

        event = Event.last
        expect(event.type).to eq('audit.service_binding.create')
        expect(event.actee).to eq(service_binding.guid)
        expect(event.actee_type).to eq('v3-service-binding')
      end

      context 'when the instance has another operation in progress' do
        it 'fails' do
          ServiceInstanceOperation.make(service_instance_id: service_instance.id, state: 'in progress')

          expect {
            service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
          }.to raise_error do |e|
            expect(e).to be_a(CloudController::Errors::ApiError)
            expect(e.message).to include('in progress')
          end
        end
      end

      context 'when the service is not bindable' do
        before do
          service_instance.service.bindable = false
          service_instance.service.save
        end

        it 'raises ServiceInstanceNotBindable' do
          expect {
            service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
          }.to raise_error(ServiceBindingCreate::ServiceInstanceNotBindable)
        end
      end

      context 'when the service binding is invalid' do
        before do
          allow_any_instance_of(ServiceBindingModel).to receive(:valid?).and_return(false)
        end

        it 'raises InvalidServiceBinding' do
          expect {
            service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
          }.to raise_error(ServiceBindingCreate::InvalidServiceBinding)
        end
      end

      context 'when volume mount services are disabled and the service requires volume_mount' do
        let(:volume_mount_services_enabled) { false }
        let(:service_instance) { ManagedServiceInstance.make(:volume_mount, space_guid: app_model.space.guid) }

        it 'raises a VolumeMountServiceDisabled error' do
          expect {
            service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
          }.to raise_error ServiceBindingCreate::VolumeMountServiceDisabled
        end
      end

      describe 'orphan mitigation situations' do
        context 'when the broker returns an error on creation' do
          before do
            stub_bind(service_instance, status: 500)
          end

          it 'does not create a binding' do
            expect {
              service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
            }.to raise_error VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse

            expect(ServiceBindingModel.count).to eq 0
          end
        end

        context 'when broker request is successful but the database fails to save the binding (Hail Mary)' do
          before do
            stub_bind(service_instance)
            stub_request(:delete, service_binding_url_pattern)

            allow(service_binding_create).to receive(:logger).and_return(logger)
            allow_any_instance_of(ServiceBindingModel).to receive(:save).and_raise('meow')
            allow(logger).to receive(:error)
            allow(logger).to receive(:info)

            expect {
              service_binding_create.create(app_model, service_instance, message, volume_mount_services_enabled)
            }.to raise_error('meow')
          end

          it 'immediately attempts to unbind the service instance' do
            expect(a_request(:put, service_binding_url_pattern)).to have_been_made.times(1)
            expect(a_request(:delete, service_binding_url_pattern)).to have_been_made.times(1)
          end

          it 'does not try to enqueue a delayed job for orphan mitigation' do
            orphan_mitigating_job = Delayed::Job.first
            expect(orphan_mitigating_job).to be_nil
          end

          context 'when the orphan mitigation unbind fails' do
            before do
              stub_request(:delete, service_binding_url_pattern).
                to_return(status: 500, body: {}.to_json)
            end

            it 'logs that the unbind failed' do
              expect(logger).to have_received(:error).with /Failed to save/
              expect(logger).to have_received(:error).with /Unable to delete orphaned service binding/
            end
          end
        end
      end
    end
  end
end
