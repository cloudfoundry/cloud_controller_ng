require 'spec_helper'

module VCAP::CloudController
  describe AppObserver do
    let(:stagers) { double(:stagers, stager_for_app: stager) }
    let(:runners) { double(:runners, runner_for_app: runner) }
    let(:stager) { double(:stager) }
    let(:runner) { double(:runner, stop: nil, start: nil) }
    let(:app) do
      double(
        :app,
        package_hash: package_hash,
        guid: 'app-guid',
        previous_changes: previous_changes,
        started?: app_started,
        needs_staging?: app_needs_staging,
        buildpack_cache_key: key,
      )
    end
    let(:app_started) { false }
    let(:app_needs_staging) { false }
    let(:previous_changes) { nil }
    let(:package_hash) { nil }
    let(:key) { nil }

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

      it "deletes the app's buildpack cache" do
        delete_buildpack_cache_jobs = Delayed::Job.where("handler like '%buildpack_cache_blobstore%'")
        expect { subject }.to change { delete_buildpack_cache_jobs.count }.by(1)
        job = delete_buildpack_cache_jobs.last

        expect(job.handler).to include(key)
        expect(job.queue).to eq('cc-generic')
      end

      context 'when the app has no package hash' do
        let(:package_hash) { nil }

        it "does not delete the app's package" do
          delete_package_jobs = Delayed::Job.where("handler like '%package_blobstore%'")
          expect { subject }.to_not change { delete_package_jobs.count }
        end
      end

      context 'when the app has a package hash' do
        let(:package_hash) { 'package-hash' }

        it 'deletes the package' do
          delete_package_jobs = Delayed::Job.where("handler like '%package_blobstore%'")
          expect { subject }.to change { delete_package_jobs.count }.by(1)
          job = delete_package_jobs.last
          expect(job.handler).to include(app.guid)
          expect(job.queue).to eq('cc-generic')
        end
      end
    end

    describe '.updated' do
      subject { AppObserver.updated(app) }

      context 'when the app state has changed' do
        let(:previous_changes) { { state: 'state-change' } }

        context 'if the app has not been started' do
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

        context 'if the app has been started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'validates and stages the app' do
              expect(stagers).to receive(:validate_app).with(app)
              expect(stager).to receive(:stage_app)
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

      context 'when the diego flag on the app has changed' do
        let(:previous_changes) { { diego: 'diego-change' } }

        context 'if the app has not been started' do
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

        context 'if the app has been started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'validates and stages the app' do
              expect(stagers).to receive(:validate_app).with(app)
              expect(stager).to receive(:stage_app)
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

        context 'if the app has not been started' do
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

        context 'if the app has been started' do
          let(:app_started) { true }

          it 'does not stop the app' do
            expect(runner).to_not receive(:stop)
            subject
          end

          context 'when the app needs staging' do
            let(:app_needs_staging) { true }

            it 'validates and stages the app' do
              expect(stagers).to receive(:validate_app).with(app)
              expect(stager).to receive(:stage_app)
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

      context 'when the app instances have changed' do
        let(:previous_changes) { { instances: 'something' } }

        context 'if the app has not been started' do
          let(:app_started) { false }

          it 'does not scale the app' do
            expect(runner).to_not receive(:scale)
            subject
          end
        end

        context 'if the app has been started' do
          let(:app_started) { true }

          it 'scales the app' do
            expect(runner).to receive(:scale)
            subject
          end
        end
      end
    end

    describe '.routes_changed' do
      subject { AppObserver.routes_changed(app) }

      context 'if the app has not been started' do
        let(:app_started) { false }

        it 'does not update routes' do
          expect(runner).to_not receive(:update_routes)
          subject
        end
      end

      context 'when the app is started' do
        let(:app_started) { true }

        it 'updates routes' do
          expect(runner).to receive(:update_routes)
          subject
        end
      end
    end
  end
end
