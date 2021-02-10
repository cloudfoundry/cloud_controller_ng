require 'spec_helper'
require 'actions/v2/services/service_binding_delete'

module VCAP::CloudController
  RSpec.describe ServiceBindingDelete do
    subject(:service_binding_delete) { ServiceBindingDelete.new(UserAuditInfo.new(user_guid: user_guid, user_email: user_email), accepts_incomplete) }
    let(:accepts_incomplete) { false }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }
    let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
    let(:service_binding) { ServiceBinding.make }
    let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }
    let(:service_instance) { service_binding.service_instance }

    describe '#foreground_delete_request' do
      let(:service_binding) { ServiceBinding.make }
      let(:service_instance) { service_binding.service_instance }
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
      let(:service_binding_url_pattern) { %r{/v2/service_instances/#{service_instance.guid}/service_bindings/} }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:unbind).and_return({ async: false })
        stub_request(:delete, service_binding_url_pattern)
      end

      it 'deletes the service binding' do
        service_binding_delete.foreground_delete_request(service_binding)
        expect(service_binding.exists?).to be_falsey
      end

      it 'creates an audit.service_binding.delete event' do
        service_binding_delete.foreground_delete_request(service_binding)

        event = Event.last
        expect(event.type).to eq('audit.service_binding.delete')
        expect(event.actee).to eq(service_binding.guid)
        expect(event.actee_type).to eq('service_binding')
      end

      it 'asks the broker to unbind the instance' do
        expect(client).to receive(:unbind).with(service_binding, user_guid: user_guid, accepts_incomplete: false)
        service_binding_delete.foreground_delete_request(service_binding)
      end

      context 'when the service instance has another operation in progress' do
        before do
          service_binding.service_instance.service_instance_operation = ServiceInstanceOperation.make(state: 'in progress')
        end

        it 'raises an error' do
          expect {
            service_binding_delete.foreground_delete_request(service_binding)
          }.to raise_error(CloudController::Errors::ApiError, /in progress/)
        end
      end

      context 'when the service binding has create operation in progress' do
        before do
          service_binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'create')
        end

        it 'deletes the binding' do
          service_binding_delete.foreground_delete_request(service_binding)
          expect(service_binding.exists?).to be_falsey
        end
      end

      context 'when the service binding has anything other than create operation in progress' do
        before do
          service_binding.service_binding_operation = ServiceBindingOperation.make(state: 'in progress', type: 'delete')
        end

        it 'raises an error' do
          expect {
            service_binding_delete.foreground_delete_request(service_binding)
          }.to raise_error(CloudController::Errors::ApiError, /in progress/)
        end
      end

      context 'when the service broker client raises an error' do
        let(:error) { StandardError.new('kablooey') }

        before do
          allow(client).to receive(:unbind).and_raise(error)
        end

        it 'decorates the error with app name and service instance name' do
          expect {
            service_binding_delete.foreground_delete_request(service_binding)
          }.to raise_error(
            "An unbind operation for the service binding between app #{service_binding.app.name} and service instance #{service_binding.service_instance.name} failed: kablooey")
        end
      end
    end

    describe '#background_delete_request' do
      let(:service_binding) { ServiceBinding.make }

      before do
        allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:unbind).and_return({ async: false })
      end

      it 'returns a delete job for the service binding' do
        job = service_binding_delete.background_delete_request(service_binding)

        expect(job).to be_a_fully_wrapped_job_of(Jobs::DeleteActionJob)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(service_binding.exists?).to be_falsey
      end
    end

    describe '#delete' do
      let(:service_binding1) { ServiceBinding.make }
      let(:service_binding2) { ServiceBinding.make }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:unbind).and_return({ async: false })
        stub_request(:delete, service_binding_url_pattern)
      end

      it 'deletes multiple bindings' do
        service_binding_delete.delete([service_binding1, service_binding2])
        expect(service_binding1).not_to exist
        expect(service_binding2).not_to exist
      end

      context 'when accepts_incomplete is true' do
        let(:accepts_incomplete) { true }

        it 'asks the broker to unbind the instance async' do
          expect(client).to receive(:unbind).with(service_binding, user_guid: user_guid, accepts_incomplete: true)
          service_binding_delete.delete(service_binding)
        end

        context 'when the broker responds asynchronously' do
          let(:service_binding_operation) {}

          before do
            allow(client).to receive(:unbind).and_return({ async: true, operation: '123' })
            allow(client).to receive(:fetch_service_binding_last_operation).and_return({})
            service_binding.service_binding_operation = service_binding_operation
          end

          it 'should keep the service binding' do
            service_binding_delete.foreground_delete_request(service_binding)

            expect(service_binding.exists?).to be_truthy
          end

          it 'should create an audit event' do
            service_binding_delete.foreground_delete_request(service_binding)

            event = Event.last
            expect(event.type).to eq('audit.service_binding.start_delete')
            expect(event.actee).to eq(service_binding.guid)
            expect(event.actee_type).to eq('service_binding')
          end

          context 'when the binding already has an operation' do
            let(:service_binding_operation) { ServiceBindingOperation.make }

            it 'updates the binding operation in the model' do
              service_binding_delete.delete(service_binding)
              service_binding.reload

              expect(service_binding.last_operation.type).to eql('delete')
              expect(service_binding.last_operation.state).to eql('in progress')
            end

            it 'service binding operation has broker provided operation' do
              service_binding_delete.delete(service_binding)
              service_binding.reload

              expect(service_binding.last_operation.broker_provided_operation).to eq('123')
            end
          end

          context 'when the binding does not already have an operation' do
            it 'updates the binding operation in the model' do
              service_binding_delete.delete(service_binding)
              service_binding.reload

              expect(service_binding.last_operation.type).to eql('delete')
              expect(service_binding.last_operation.state).to eql('in progress')
            end

            it 'service binding operation has broker provided operation' do
              service_binding_delete.delete(service_binding)
              service_binding.reload

              expect(service_binding.last_operation.broker_provided_operation).to eq('123')
            end

            it 'there should be no warnings or errors' do
              errors, warnings = service_binding_delete.delete(service_binding)
              expect(warnings).to be_empty
              expect(errors).to be_empty
            end
          end
        end

        context 'when the broker responds synchronously' do
          before do
            allow(client).to receive(:unbind).and_return({ async: false })
          end

          it 'there should be no warnings or errors' do
            errors, warnings = service_binding_delete.delete(service_binding)
            expect(warnings).to be_empty
            expect(errors).to be_empty
          end
        end
      end

      context 'when accepts_incomplete is false' do
        let(:accepts_incomplete) { false }

        it 'asks the broker to unbind the instance sync' do
          expect(client).to receive(:unbind).with(service_binding, user_guid: user_guid, accepts_incomplete: false)
          service_binding_delete.delete(service_binding)
        end

        context 'when the broker unexpectedly responds asynchronously' do
          let(:service_binding_operation) {}
          let(:expected_warning) do
            ['The service broker responded asynchronously to the unbind request, but the accepts_incomplete query parameter was false or not given.',
             'The service binding may not have been successfully deleted on the service broker.'].join(' ')
          end

          before do
            allow(client).to receive(:unbind).and_return({ async: true })
            allow(client).to receive(:fetch_service_binding_last_operation).and_return({})
            service_binding.service_binding_operation = service_binding_operation
          end

          it 'should immediately delete the binding' do
            service_binding_delete.delete(service_binding)
            expect(service_binding.exists?).to be_falsey
          end

          it 'should create an audit event' do
            service_binding_delete.delete(service_binding)

            event = Event.last
            expect(event.type).to eq('audit.service_binding.delete')
            expect(event.actee).to eq(service_binding.guid)
            expect(event.actee_type).to eq('service_binding')
          end

          it 'should respond with a warning' do
            errors, warnings = service_binding_delete.delete(service_binding)
            expect(warnings).to match_array([expected_warning])
            expect(errors).to be_empty
          end

          context 'when delete is called with multiple bindings' do
            it 'should return warnings for all bindings' do
              errors, warnings = service_binding_delete.delete([service_binding, ServiceBinding.make])
              expect(warnings).to match_array([expected_warning, expected_warning])
              expect(errors).to be_empty
            end
          end
        end
      end

      context 'when accepts_incomplete is not provided as an argument' do
        let(:service_binding_delete) { ServiceBindingDelete.new(UserAuditInfo.new(user_guid: user_guid, user_email: user_email)) }

        it 'defaults to false and asks the broker to unbind the instance sync' do
          expect(client).to receive(:unbind).with(service_binding, user_guid: user_guid, accepts_incomplete: false)
          service_binding_delete.delete(service_binding)
        end
      end
    end

    describe '#can_return_warnings?' do
      it 'returns true' do
        expect(service_binding_delete.can_return_warnings?).to be true
      end
    end
  end
end
