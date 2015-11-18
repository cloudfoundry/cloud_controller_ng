require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe OrphanedPackagesCleanup do
      let(:cutoff_age_in_days) { 1 }
      let(:tmp_dir) { Dir.mktmpdir }
      let(:package_blobstore) { blobstore('package') }
      let(:bits_cache) { blobstore('global_app_bits_cache') }
      let(:package_files) { package_blobstore.files }
      let(:packager) do
        AppBitsPackage.new(package_blobstore, bits_cache, 256, tmp_dir)
      end
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

      subject(:job) { OrphanedPackagesCleanup.new(cutoff_age_in_days) }

      it { is_expected.to be_a_valid_job }

      before do
        Fog.unmock!
        allow(CloudController::DependencyLocator.instance).
          to receive(:package_blobstore).and_return(package_blobstore)
      end

      after { Fog.mock! }

      context 'given a v2 app with uploaded app bits' do
        let!(:app) do
          VCAP::CloudController::AppFactory.make.tap do |app|
            c = CloudController::Blobstore::FingerprintsCollection.new([])
            packager.create(app, app_zip, c)
          end
        end

        context 'when app is destroyed' do
          before { app.destroy }

          it 'removes orphaned blobs which are older then cutoff_age_in_days' do
            Timecop.freeze(Time.now + cutoff_age_in_days + 1.day) do
              expect { job.perform }.to change { package_files.reload }.to([])
            end
          end

          it 'skips recently orphaned blobs' do
            expect { job.perform }.to_not change { package_files.reload }
            expect(package_files.reload.size).to eq 1
          end
        end

        it 'skips blobs which belong to an application' do
          expect { job.perform }.to_not change { package_files.reload }
        end
      end

      context 'given a v3 package' do
        let!(:package) do
          VCAP::CloudController::PackageModel.create(
            state: VCAP::CloudController::PackageModel::CREATED_STATE
          ).tap do |package|
            packager.create_package_in_blobstore(package.guid, app_zip)
          end
        end

        context 'when package is destroyed' do
          before { package.destroy }

          it 'removes orphaned blobs which are older then cutoff_age_in_days' do
            Timecop.freeze(Time.now + cutoff_age_in_days + 1.day) do
              expect { job.perform }.to change { package_files.reload }.to([])
            end
          end

          it 'skips recently orphaned blobs' do
            expect { job.perform }.to_not change { package_files.reload }
            expect(package_files.reload.size).to eq 1
          end
        end

        it 'skips blobs which belong to an application' do
          expect { job.perform }.to_not change { package_files.reload }
          expect(package_files.reload.size).to eq 1
        end
      end

      context 'given an blob with an unexpected key' do
        before do
          package_blobstore.cp_to_blobstore(app_zip, 'foo_blob')
        end

        it 'skips blobs with unexpected keys' do
          Timecop.freeze(Time.now + cutoff_age_in_days + 1.day) do
            expect { job.perform }.to_not change { package_files.reload }
            expect(package_files.reload.size).to eq 1
          end
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to eq(:orphaned_packages_cleanup)
      end
    end
  end
end
