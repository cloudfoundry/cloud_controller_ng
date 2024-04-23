require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ServiceOperationsInitialCleanup, job_context: :worker do
      subject(:job) { ServiceOperationsInitialCleanup.new }

      let(:fake_orphan_mitigator) { double(VCAP::Services::ServiceBrokers::V2::OrphanMitigator) }
      let(:fake_logger) { instance_double(Steno::Logger, info: nil) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:service_operations_initial_cleanup)
      end

      it 'adds 10% to the broker_client_timeout' do
        expect(job.broker_client_timeout_plus_margin).to equal(66)
      end

      def expect_no_orphan_mitigator_calls(orphan_mitigator)
        %i[cleanup_failed_provision cleanup_failed_bind cleanup_failed_key].each do |call|
          expect(orphan_mitigator).not_to have_received(call)
        end
      end

      describe 'perform' do
        let!(:service_instance) { ManagedServiceInstance.make }
        let!(:service_binding) { ServiceBinding.make }
        let!(:service_key) { ServiceKey.make }
        let!(:route_binding) { RouteBinding.make }

        before do
          allow(Steno).to receive(:logger).and_return(fake_logger)

          allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).and_return(fake_orphan_mitigator)
          allow(fake_orphan_mitigator).to receive(:cleanup_failed_provision).with(service_instance)
          allow(fake_orphan_mitigator).to receive(:cleanup_failed_bind).with(service_binding)
          allow(fake_orphan_mitigator).to receive(:cleanup_failed_key).with(service_key)
        end

        context 'when there are no service instance operations in state create/initial' do
          let!(:service_instance_operation) { ServiceInstanceOperation.make(service_instance_id: service_instance.id, type: 'create', state: 'succeeded') }

          it 'does nothing' do
            job.perform

            expect(service_instance_operation.reload.type).to eq('create')
            expect(service_instance_operation.reload.state).to eq('succeeded')
            expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
          end
        end

        context 'when there is one service instance operation in state create/initial' do
          let!(:service_instance_operation) { ServiceInstanceOperation.make(service_instance_id: service_instance.id, type: 'create', state: 'initial') }

          context 'and the service broker connection timeout has not yet passed' do
            it 'does nothing' do
              job.perform

              expect(service_instance_operation.reload.type).to eq('create')
              expect(service_instance_operation.reload.state).to eq('initial')
              expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
            end
          end

          context 'and the service broker connection timeout has passed' do
            let(:expired_time) { Time.now.utc - 2.seconds }

            before do
              TestConfig.override(broker_client_timeout_seconds: 1)
              service_instance_operation.this.update(updated_at: expired_time)
            end

            it 'sets the operation state to create/failed and triggers the orphan mitigation' do
              job.perform

              expect(service_instance_operation.reload.type).to eq('create')
              expect(service_instance_operation.reload.state).to eq('failed')
              expect(service_instance_operation.reload.description).to eq('Operation was stuck in "initial" state. Set to "failed" by cleanup job.')
              expect(fake_logger).to have_received(:info).with("ServiceInstance #{service_instance[:guid]} is stuck in state 'create'/'initial'. " \
                                                               "Setting state to 'failed' and triggering orphan mitigation.")
              expect(fake_orphan_mitigator).to have_received(:cleanup_failed_provision).with(service_instance)
            end
          end
        end

        context 'when there are no service instance binding operations in state create/initial' do
          let!(:service_binding_operation) { ServiceBindingOperation.make(service_binding_id: service_binding.id, type: 'create', state: 'succeeded') }

          it 'does nothing' do
            job.perform

            expect(service_binding_operation.reload.type).to eq('create')
            expect(service_binding_operation.reload.state).to eq('succeeded')
            expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
          end
        end

        context 'when there is one service instance binding operation in state create/initial' do
          let!(:service_binding_operation) { ServiceBindingOperation.make(service_binding_id: service_binding.id, type: 'create', state: 'initial') }

          context 'and the service broker connection timeout has not yet passed' do
            it 'does nothing' do
              job.perform

              expect(service_binding_operation.reload.type).to eq('create')
              expect(service_binding_operation.reload.state).to eq('initial')
              expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
            end
          end

          context 'and the service broker connection timeout has passed' do
            let(:expired_time) { Time.now.utc - 2.seconds }

            before do
              TestConfig.override(broker_client_timeout_seconds: 1)
              service_binding_operation.this.update(updated_at: expired_time)
            end

            it 'sets the operation state to create/failed and triggers the orphan mitigation' do
              job.perform

              expect(service_binding_operation.reload.type).to eq('create')
              expect(service_binding_operation.reload.state).to eq('failed')
              expect(service_binding_operation.reload.description).to eq('Operation was stuck in "initial" state. Set to "failed" by cleanup job.')
              expect(fake_logger).to have_received(:info).with("ServiceBinding #{service_binding[:guid]} is stuck in state 'create'/'initial'. " \
                                                               "Setting state to 'failed' and triggering orphan mitigation.")
              expect(fake_orphan_mitigator).to have_received(:cleanup_failed_bind).with(service_binding)
            end
          end
        end

        context 'when there are no service key operations in state create/initial' do
          let!(:service_key_operation) { ServiceKeyOperation.make(service_key_id: service_key.id, type: 'create', state: 'succeeded') }

          it 'does nothing' do
            job.perform

            expect(service_key_operation.reload.type).to eq('create')
            expect(service_key_operation.reload.state).to eq('succeeded')
            expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
          end
        end

        context 'when there is one service key operation in state create/initial' do
          let!(:service_key_operation) { ServiceKeyOperation.make(service_key_id: service_key.id, type: 'create', state: 'initial') }

          context 'and the service broker connection timeout has not yet passed' do
            it 'does nothing' do
              job.perform

              expect(service_key_operation.reload.type).to eq('create')
              expect(service_key_operation.reload.state).to eq('initial')
              expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
            end
          end

          context 'and the service broker connection timeout has passed' do
            let(:expired_time) { Time.now.utc - 2.seconds }

            before do
              TestConfig.override(broker_client_timeout_seconds: 1)
              service_key_operation.this.update(updated_at: expired_time)
            end

            it 'sets the operation state to create/failed and triggers the orphan mitigation' do
              job.perform

              expect(service_key_operation.reload.type).to eq('create')
              expect(service_key_operation.reload.state).to eq('failed')
              expect(service_key_operation.reload.description).to eq('Operation was stuck in "initial" state. Set to "failed" by cleanup job.')
              expect(fake_logger).to have_received(:info).with("ServiceKey #{service_key[:guid]} is stuck in state 'create'/'initial'. " \
                                                               "Setting state to 'failed' and triggering orphan mitigation.")
              expect(fake_orphan_mitigator).to have_received(:cleanup_failed_key).with(service_key)
            end
          end
        end

        context 'when there are no route binding operations in state create/initial' do
          let!(:route_binding_operation) { RouteBindingOperation.make(route_binding_id: route_binding.id, type: 'create', state: 'succeeded') }

          it 'does nothing' do
            job.perform

            expect(route_binding_operation.reload.type).to eq('create')
            expect(route_binding_operation.reload.state).to eq('succeeded')
            expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
          end
        end

        context 'when there is one route binding operation in state create/initial' do
          let!(:route_binding_operation) { RouteBindingOperation.make(route_binding_id: route_binding.id, type: 'create', state: 'initial') }

          context 'and the service broker connection timeout has not yet passed' do
            it 'does nothing' do
              job.perform

              expect(route_binding_operation.reload.type).to eq('create')
              expect(route_binding_operation.reload.state).to eq('initial')
              expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
            end
          end

          context 'and the service broker connection timeout has passed' do
            let(:expired_time) { Time.now.utc - 2.seconds }

            before do
              TestConfig.override(broker_client_timeout_seconds: 1)
              route_binding_operation.this.update(updated_at: expired_time)
            end

            it 'sets the operation state to create/failed and triggers the orphan mitigation' do
              job.perform

              expect(route_binding_operation.reload.type).to eq('create')
              expect(route_binding_operation.reload.state).to eq('failed')
              expect(route_binding_operation.reload.description).to eq('Operation was stuck in "initial" state. Set to "failed" by cleanup job.')
              expect(fake_logger).to have_received(:info).with("RouteBinding #{route_binding[:guid]} is stuck in state 'create'/'initial'. " \
                                                               "Setting state to 'failed' and triggering orphan mitigation.")
              expect_no_orphan_mitigator_calls(fake_orphan_mitigator)
            end
          end
        end
      end
    end
  end
end
