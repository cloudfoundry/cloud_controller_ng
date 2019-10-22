require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceInstanceDeprovisioner do
    let(:event_repository) { Repositories::ServiceEventRepository.new(UserAuditInfo.new(user_guid: User.make.guid, user_email: 'email')) }
    let(:deprovisioner) { ServiceInstanceDeprovisioner.new(event_repository) }

    describe '#deprovision_service_instance' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:fake_job) { instance_double(Jobs::DeleteActionJob) }
      let(:fake_action) { instance_double(ServiceInstanceDelete, can_return_warnings?: true) }
      let(:some_boolean) { false }

      before do
        allow(Jobs::DeleteActionJob).to receive(:new).and_return(fake_job)
        allow(fake_job).to receive(:perform).and_return([])
      end

      context 'when accepts_incomplete is true' do
        it 'creates a service instance delete action' do
          accepts_incomplete = true

          expect(ServiceInstanceDelete).to receive(:new).
            with({ accepts_incomplete: true, event_repository: event_repository }).once.
            and_return(fake_action)

          deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, some_boolean)
        end
      end

      context 'when accepts_incomplete is false' do
        it 'creates a service instance delete action' do
          accepts_incomplete = false

          expect(ServiceInstanceDelete).to receive(:new).
            with({ accepts_incomplete: false, event_repository: event_repository }).once.
            and_return(fake_action)

          deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, some_boolean)
        end
      end

      it 'creates a delete action job' do
        expect(Jobs::DeleteActionJob).to receive(:new).
          with(ServiceInstance, service_instance.guid, instance_of(ServiceInstanceDelete)).once

        deprovisioner.deprovision_service_instance(service_instance, some_boolean, some_boolean)
      end

      context 'when async is false' do
        let(:async) { false }

        context 'and accepts_incomplete is true' do
          let(:accepts_incomplete) { true }

          it 'executes the job immediately' do
            expect(fake_job).to receive(:perform).once

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          it 'does not enqueue the job' do
            expect(Jobs::Enqueuer).not_to receive(:new)

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          context 'and the delete job returned warnings' do
            before do
              allow(fake_job).to receive(:perform).and_return(['warning-1', 'warning-2'])
            end

            it 'returns nil and the warnings' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, ['warning-1', 'warning-2']])
            end
          end

          context 'and the delete job did not return warnings' do
            it 'returns nil and an empty array' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, []])
            end
          end
        end

        context 'and accepts_incomplete is false' do
          let(:accepts_incomplete) { false }

          it 'executes the job immediately' do
            expect(fake_job).to receive(:perform).once

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          it 'does not enqueue the job' do
            expect(Jobs::Enqueuer).not_to receive(:new)

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          context 'and the delete job returned warnings' do
            before do
              allow(fake_job).to receive(:perform).and_return(['warning-1', 'warning-2'])
            end

            it 'returns nil and the warnings' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, ['warning-1', 'warning-2']])
            end
          end

          context 'and the delete job did not return warnings' do
            it 'returns nil and an empty array' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, []])
            end
          end
        end
      end

      context 'when async is true' do
        let(:async) { true }

        context 'and accepts_incomplete is false' do
          let(:accepts_incomplete) { false }

          it 'enqueues a job' do
            fake_enqueuer = instance_double(Jobs::Enqueuer)
            expect(Jobs::Enqueuer).to receive(:new).with(duck_type(:perform), { queue: Jobs::Queues.generic }).and_return(fake_enqueuer)
            expect(fake_enqueuer).to receive(:enqueue).once

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          it 'returns the enqueued job and an empty warnings array' do
            result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
            expect(result).to match_array([be_instance_of(Delayed::Job), []])
          end
        end

        context 'and accepts_incomplete is true' do
          let(:accepts_incomplete) { true }

          it 'executes the job immediately' do
            expect(fake_job).to receive(:perform).once

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          it 'does not enqueue a job' do
            expect(Jobs::Enqueuer).not_to receive(:new)

            deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
          end

          context 'and the delete job returned warnings' do
            before do
              allow(fake_job).to receive(:perform).and_return(['warning-1', 'warning-2'])
            end

            it 'returns nil and the warnings' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, ['warning-1', 'warning-2']])
            end
          end

          context 'and the delete job did not return warnings' do
            it 'returns nil and an empty array' do
              result = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)
              expect(result).to match_array([nil, []])
            end
          end
        end
      end
    end
  end
end
