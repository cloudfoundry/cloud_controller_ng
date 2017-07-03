require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppObserver do
    let(:stagers) { double(:stagers, stager_for_app: stager) }
    let(:runners) { instance_double(Runners, runner_for_app: runner) }
    let(:stager) { double(:stager) }
    let(:runner) { instance_double(Diego::Runner, stop: nil, start: nil) }
    let(:app_active) { true }
    let(:diego) { false }
    let(:app) do
      instance_double(ProcessModel,
        package_hash: package_hash,
        guid: 'app-guid',
        previous_changes: previous_changes,
        started?: app_started,
        needs_staging?: app_needs_staging,
        active?: app_active,
        # TODO: why did we remove `buildpack_cache_key: key`?
        diego: diego,
        staging?: staging?,
        current_droplet: nil,
        memory: 12,
        disk_quota: 34,
      )
    end
    let(:app_started) { false }
    let(:app_needs_staging) { false }
    let(:previous_changes) { nil }
    let(:package_hash) { nil }
    let(:key) { nil }
    let(:staging?) { false }

    before do
      AppObserver.configure(stagers, runners)
    end

    describe '.deleted' do
      let(:key) { 'my-cache-key' }
      subject { AppObserver.deleted(app) }

      it 'stops the app' do
        expect(runner).to receive(:stop)
        subject
      end

      context 'diego app' do
        let(:diego) { true }

        it 'does not care if diego is unavailable' do
          allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
          expect { subject }.not_to raise_error
        end
      end
    end

    describe '.updated' do
      subject { AppObserver.updated(app) }

      context 'when the app state is changed' do
        let(:previous_changes) { { state: 'original-state' } }

        context 'if the desired app state is stopped' do
          let(:app_started) { false }

          it 'stops the app' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the app' do
            expect(runner).to_not receive(:start)
            subject
          end

          context 'diego app' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end

        context 'if the desired app state is started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'does not start the app' do
              expect(runner).to_not receive(:start)
              subject
            end
          end

          context 'when the app does not need staging' do
            let(:app_needs_staging) { false }

            it 'starts the app' do
              expect(runner).to receive(:start)
              subject
            end
          end

          context 'diego app' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:start).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end
      end

      context 'when the diego flag on the app has changed' do
        let(:previous_changes) { { diego: 'diego-change' } }

        context 'if the desired state of the app is stopped' do
          let(:app_started) { false }

          it 'stops the app' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the app' do
            expect(runner).to_not receive(:start)
            subject
          end
        end

        context 'if the desired state of the app is started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'does not start the app' do
              expect(runner).not_to receive(:start)
              subject
            end
          end

          context 'when the app does not need staging' do
            let(:app_needs_staging) { false }

            it 'starts the app' do
              expect(runner).to receive(:start)
              subject
            end
          end
        end
      end

      context 'when the enable_ssh flag on the app has changed' do
        let(:previous_changes) { { enable_ssh: true } }

        context 'if the desired state of the app is stopped' do
          let(:app_started) { false }

          it 'stops the app' do
            expect(runner).to receive(:stop)
            subject
          end

          it 'does not start the app' do
            expect(runner).to_not receive(:start)
            subject
          end

          context 'diego app' do
            let(:diego) { true }

            it 'does not care if diego is unavailable' do
              allow(runner).to receive(:stop).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
              expect { subject }.not_to raise_error
            end
          end
        end

        context 'if the desired state of the app is started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'does not start the app' do
              expect(runner).not_to receive(:start)
              subject
            end
          end

          context 'when the app does not need staging' do
            let(:app_needs_staging) { false }

            it 'starts the app' do
              expect(runner).to receive(:start)
              subject
            end

            context 'diego app' do
              let(:diego) { true }

              it 'does not care if diego is unavailable' do
                allow(runner).to receive(:start).and_raise(VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError)
                expect { subject }.not_to raise_error
              end
            end
          end
        end
      end

      context 'when the app instances have changed' do
        let(:previous_changes) { { instances: 'something' } }

        context 'if the desired state of the app is stopped' do
          let(:app_started) { false }

          it 'does not scale the app' do
            expect(runner).to_not receive(:scale)
            subject
          end

          context 'when Docker is enabled' do
            let(:app_active) { true }

            it 'does not scale the app' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end

          context 'when Docker is disabled' do
            let(:app_active) { false }

            it 'does not scale the app' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end
        end

        context 'if the desired state of the app is started' do
          let(:app_started) { true }

          it 'scales the app' do
            expect(runner).to receive(:scale)
            subject
          end

          context 'when Docker is enabled' do
            let(:app_active) { true }

            it 'scales the app' do
              expect(runner).to receive(:scale)
              subject
            end
          end

          context 'when Docker is disabled' do
            let(:app_active) { false }

            it 'does not scale the app' do
              expect(runner).to_not receive(:scale)
              subject
            end
          end

          context 'diego app' do
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
