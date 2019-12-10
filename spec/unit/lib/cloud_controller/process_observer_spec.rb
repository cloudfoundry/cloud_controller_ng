require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessObserver do
    let(:stagers) { double(:stagers, stager_for_build: stager) }
    let(:runners) { instance_double(Runners, runner_for_process: runner) }
    let(:stager) { double(:stager) }
    let(:runner) { instance_double(Diego::Runner, stop: nil, start: nil) }
    let(:process_active) { true }
    let(:diego) { false }
    let(:process) do
      instance_double(ProcessModel,
        package_hash: package_hash,
        guid: 'process-guid',
        previous_changes: previous_changes,
        started?: process_started,
        needs_staging?: process_needs_staging,
        active?: process_active,
        # TODO: why did we remove `buildpack_cache_key: key`?
        diego: diego,
        staging?: staging?,
        desired_droplet: nil,
        memory: 12,
        disk_quota: 34,
        revisions_enabled?: false,
      )
    end
    let(:process_started) { false }
    let(:process_needs_staging) { false }
    let(:previous_changes) { nil }
    let(:package_hash) { nil }
    let(:key) { nil }
    let(:staging?) { false }

    before do
      ProcessObserver.configure(stagers, runners)
    end

    describe '.deleted' do
      let(:key) { 'my-cache-key' }
      subject { ProcessObserver.deleted(process) }

      it 'stops the process' do
        expect(runner).to receive(:stop)
        subject
      end

      context 'diego process' do
        let(:diego) { true }

        it 'does not care if diego is unavailable' do
          allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
          expect { subject }.not_to raise_error
        end
      end
    end

    describe '.updated' do
      subject { ProcessObserver.updated(process) }

      context 'when the process state is changed' do
        let(:previous_changes) { { state: 'original-state' } }

        context 'if the desired process state is stopped' do
          let(:process_started) { false }

          it 'stops the process' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the process' do
            expect(runner).to_not receive(:start)
            subject
          end

          context 'diego process' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end

        context 'if the desired process state is started' do
          let(:process_started) { true }

          it 'does not stop the process' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the process needs staging' do
            let(:process_needs_staging) { true }

            it 'does not start the process' do
              expect(runner).to_not receive(:start)
              subject
            end
          end

          context 'when the process does not need staging' do
            let(:process_needs_staging) { false }

            it 'starts the process' do
              expect(runner).to receive(:start)
              subject
            end

            context 'when revisions are enabled' do
              let(:process) { ProcessModel.make }
              let(:app) { process.app }
              let!(:revision) { RevisionModel.make(app: app) }

              before do
                app.update(revisions_enabled: true)
              end

              it 'associates the revision to the process', isolation: :truncation do
                expect(runner).to receive(:start)
                process.update(state: ProcessModel::STARTED)
                expect(app.latest_revision).not_to be_nil
                expect(process.reload.revision).to eq(app.latest_revision)
              end
            end
          end

          context 'diego process' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:start).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end
      end

      context 'when the diego flag on the process has changed' do
        let(:previous_changes) { { diego: 'diego-change' } }

        context 'if the desired state of the process is stopped' do
          let(:process_started) { false }

          it 'stops the process' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the process' do
            expect(runner).to_not receive(:start)
            subject
          end
        end

        context 'if the desired state of the process is started' do
          let(:process_started) { true }

          it 'does not stop the process' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the process needs staging' do
            let(:process_needs_staging) { true }

            it 'does not start the process' do
              expect(runner).not_to receive(:start)
              subject
            end
          end

          context 'when the process does not need staging' do
            let(:process_needs_staging) { false }

            it 'starts the process' do
              expect(runner).to receive(:start)
              subject
            end
          end
        end
      end

      context 'when the enable_ssh flag on the process has changed' do
        let(:previous_changes) { { enable_ssh: true } }

        context 'if the desired state of the process is stopped' do
          let(:process_started) { false }

          it 'stops the process' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the process' do
            expect(runner).to_not receive(:start)
            subject
          end

          context 'diego process' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end

        context 'if the desired state of the process is started' do
          let(:process_started) { true }

          it 'does not stop the process' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the process needs staging' do
            let(:process_needs_staging) { true }

            it 'does not start the process' do
              expect(runner).not_to receive(:start)
              subject
            end
          end

          context 'when the process does not need staging' do
            let(:process_needs_staging) { false }

            it 'starts the process' do
              expect(runner).to receive(:start)
              subject
            end

            context 'diego process' do
              let(:diego) { true }

              it 'does not care if diego is unavailable' do
                allow(runner).to receive(:start).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
                expect { subject }.not_to raise_error
              end
            end
          end
        end
      end

      context 'when the process instances have changed' do
        let(:previous_changes) { { instances: 'something' } }

        context 'if the desired state of the process is stopped' do
          let(:process_started) { false }

          it 'does not scale the process' do
            expect(runner).to_not receive(:scale)
            subject
          end

          context 'when Docker is enabled' do
            let(:process_active) { true }

            it 'does not scale the process' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end

          context 'when Docker is disabled' do
            let(:process_active) { false }

            it 'does not scale the process' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end
        end

        context 'if the desired state of the process is started' do
          let(:process_started) { true }

          it 'scales the process' do
            expect(runner).to receive(:scale)
            subject
          end

          context 'when Docker is enabled' do
            let(:process_active) { true }

            it 'scales the process' do
              expect(runner).to receive(:scale)
              subject
            end
          end

          context 'when Docker is disabled' do
            let(:process_active) { false }

            it 'does not scale the process' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end

          context 'diego process' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:scale).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
