require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe OrphanedPackagesCleanup do
      let(:cleanup_after_days) { 1 }
      let(:tmp_dir) { Dir.mktmpdir }
      let(:package_blobstore) { blobstore('package') }
      let(:bits_cache) { blobstore('global_app_bits_cache') }
      let(:package_files) { package_blobstore.files }
      let(:app_zip) do
        Tempfile.new('app_zip').path.tap do |dst|
          src = File.expand_path('../../../../fixtures/good.zip', __FILE__)
          FileUtils.cp(src, dst)
        end
      end

      def blobstore(name)
        opts = { provider: 'Local', local_root: Dir.mktmpdir }
        CloudController::Blobstore::Client.new(opts, name)
      end

      subject(:job) { OrphanedPackagesCleanup.new(cleanup_after_days) }

      it { is_expected.to be_a_valid_job }

      before do
        Fog.unmock!
        allow(CloudController::DependencyLocator.instance).
          to receive(:package_blobstore).and_return(package_blobstore)
      end

      after { Fog.mock! }

      context "given a v2 app with uploaded app bits" do
        let!(:app) do
          VCAP::CloudController::AppFactory.make.tap do |app|
            c = CloudController::Blobstore::FingerprintsCollection.new([])
            p = AppBitsPackage.new(package_blobstore, bits_cache, 256, tmp_dir)
            p.create(app, app_zip, c)
          end
        end

        context "when app is destroyed" do
          before { app.destroy }

          it 'removes orphaned blobs which are older then cleanup_after_days' do
            Timecop.freeze(Time.now + cleanup_after_days + 1.day) do
              expect { job.perform }.to change { package_files.reload }.to([])
            end
          end

          it 'skips recently orphaned blobs' do
            expect { job.perform }.to_not change { package_files.reload }
          end
        end

        it 'skips blobs which belong to an application' do
          expect { job.perform }.to_not change { package_files.reload }
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to eq(:orphaned_packages_cleanup)
      end
    end
  end
end
