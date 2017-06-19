require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe OrphanedBlobsCleanup do
      subject(:job) { described_class.new }
      let(:perform_blob_cleanup) { true }
      let(:logger) { double(:logger, info: nil, error: nil) }

      it { is_expected.to be_a_valid_job }

      it 'has max_attempts 1' do
        expect(job.max_attempts).to eq 1
      end

      describe '#perform' do
        before do
          allow(job).to receive(:logger).and_return(logger)
          TestConfig.config[:perform_blob_cleanup] = perform_blob_cleanup
        end

        context 'when perform_blob_cleanup is enabled' do
          it 'starts the job' do
            job.perform
            expect(logger).to have_received(:info).with('Started orphaned blobs cleanup job')
            expect(logger).not_to have_received(:info).with('Skipping OrphanedBlobsCleanup as the `perform_blob_cleanup` manifest property is false')
          end
        end

        context 'when perform_blob_cleanup is disabled' do
          let(:perform_blob_cleanup) { false }

          it 'skips the job' do
            job.perform
            expect(logger).to have_received(:info).with('Skipping OrphanedBlobsCleanup as the `perform_blob_cleanup` manifest property is false')
            expect(job).not_to receive(:cleanup)
            expect(logger).not_to have_received(:info).with('Started orphaned blobs cleanup job')
          end
        end
      end

      describe '#cleanup' do
        let(:droplet_blobstore) { instance_double(CloudController::Blobstore::DavClient, files: droplet_files, root_dir: droplet_root_dir) }
        let(:droplet_files) { [] }
        let(:droplet_root_dir) { nil }
        let(:package_blobstore) { instance_double(CloudController::Blobstore::DavClient, files: package_files, root_dir: package_root_dir) }
        let(:package_files) { [] }
        let(:package_root_dir) { nil }
        let(:buildpack_blobstore) { instance_double(CloudController::Blobstore::FogClient, files: buildpack_files, root_dir: buildpack_root_dir) }
        let(:buildpack_files) { [] }
        let(:buildpack_root_dir) { nil }
        let(:legacy_resources_blobstore) { instance_double(CloudController::Blobstore::FogClient, files: legacy_resource_files, root_dir: legacy_resource_root_dir) }
        let(:legacy_resource_files) { [] }
        let(:legacy_resource_root_dir) { nil }

        before do
          TestConfig.config[:perform_blob_cleanup] = perform_blob_cleanup

          TestConfig.config[:packages][:app_package_directory_key]   = 'packages'
          TestConfig.config[:droplets][:droplet_directory_key]       = 'droplets'
          TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'buildpacks'
          TestConfig.config[:resource_pool][:resource_directory_key] = 'resources'

          allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(droplet_blobstore)
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)
          allow(CloudController::DependencyLocator.instance).to receive(:legacy_global_app_bits_cache).and_return(legacy_resources_blobstore)
        end

        describe 'when determining whether a blob is in use' do
          context 'when a blobstore file matches an existing droplet' do
            let!(:droplet) { DropletModel.make(guid: 'real-droplet-blob', droplet_hash: '123') }
            let(:droplet_files) { [double(:blob, key: 're/al/real-droplet-blob/123')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when a blobstore file matches an existing package' do
            let!(:package) { PackageModel.make(guid: 'real-package-blob') }
            let(:package_files) { [double(:blob, key: 're/al/real-package-blob')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when a blobstore file matches an existing buildpack' do
            let!(:buildpack) { Buildpack.make(key: 'real-buildpack-blob') }
            let(:buildpack_files) { [double(:blob, key: 're/al/real-buildpack-blob')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when the blobstore file starts with an ignored prefix' do
            let(:droplet_files) do
              [
                double(:blob, key: "#{CloudController::DependencyLocator::BUILDPACK_CACHE_DIR}/so/me/blobstore-file"),
                double(:blob, key: "#{CloudController::DependencyLocator::RESOURCE_POOL_DIR}/so/me/blobstore-file"),
              ]
            end

            it 'will never mark the blob as an orphan' do
              expect {
                job.perform
              }.to_not change { OrphanedBlob.count }
              expect(droplet_blobstore).to have_received(:files).with(OrphanedBlobsCleanup::IGNORED_DIRECTORY_PREFIXES)
            end
          end
        end

        describe 'when creating an OrphanedBlob record from a blob' do
          let(:some_files) do
            [
              double(:blob, key: 'so/me/blobstore-file'),
              double(:blob, key: 'so/me/blobstore-file2'),
            ]
          end
          let(:droplet_files) { some_files }
          let(:package_files) { some_files }
          let(:buildpack_files) { some_files }
          let(:legacy_resource_files) { some_files }

          context 'when all the blobstore buckets are different' do
            it 'should create an OrphanedBlob record for each blob in each of the blobstores' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(blobstore_type: 'package_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'droplet_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'buildpack_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'legacy_global_app_bits_cache').count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(4)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(4)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'package_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'legacy_global_app_bits_cache').dirty_count).to eq(1)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'package_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'legacy_global_app_bits_cache').dirty_count).to eq(1)
            end
          end

          context 'when all the blobstores use the same buckets as each other' do
            before do
              TestConfig.config[:packages][:app_package_directory_key]   = 'same'
              TestConfig.config[:droplets][:droplet_directory_key]       = 'same'
              TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'same'
              TestConfig.config[:resource_pool][:resource_directory_key] = 'same'
            end

            it 'it creates OrphanedBlobs for each file and marks them with the same directory_key and blobstore (as droplet_blobstore =/)' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(blobstore_type: 'droplet_blobstore').count).to eq(2)
              expect(OrphanedBlob.count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(1)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(1)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
            end
          end

          context 'when some blobstores share the same bucket' do
            before do
              TestConfig.config[:packages][:app_package_directory_key]   = 'diff'
              TestConfig.config[:droplets][:droplet_directory_key]       = 'super-diff'
              TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'same'
              TestConfig.config[:resource_pool][:resource_directory_key] = 'same'
            end

            it 'should create an OrphanedBlob record for each blob in each of the different blobstores (but overwrites each other based on the order in #blobstores)' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(blobstore_type: 'buildpack_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'package_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'droplet_blobstore').count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(3)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(3)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'package_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'package_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
            end
          end

          context 'when all the blobstores share the same bucket but some have different root_dirs' do
            let(:droplet_root_dir) { 'same' }
            let(:package_root_dir) { 'same' }
            let(:buildpack_root_dir) { 'diff' }
            let(:legacy_resource_root_dir) { nil }

            before do
              TestConfig.config[:packages][:app_package_directory_key]   = 'same'
              TestConfig.config[:droplets][:droplet_directory_key]       = 'same'
              TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'same'
              TestConfig.config[:resource_pool][:resource_directory_key] = 'same'
            end

            it 'should create an OrphanedBlob record for each blob in each of the unique blobstores' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(blobstore_type: 'droplet_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'package_blobstore').count).to eq(0)
              expect(OrphanedBlob.where(blobstore_type: 'buildpack_blobstore').count).to eq(2)
              expect(OrphanedBlob.where(blobstore_type: 'legacy_global_app_bits_cache').count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(3)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(3)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'droplet_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'buildpack_blobstore').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', blobstore_type: 'legacy_global_app_bits_cache').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', blobstore_type: 'legacy_global_app_bits_cache').dirty_count).to eq(1)
            end
          end

          context 'when there are more than NUMBER_OF_BLOBS_TO_DELETE blobs to mark as dirty' do
            let(:some_files) do
              result = []
              (OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE + 1).times do |i|
                result << double(:blob, key: "so/me/blobstore-file-#{i}")
              end
              result
            end

            it 'stops after marking NUMBER_OF_BLOBS_TO_DELETE of blobs as dirty' do
              expect {
                job.perform
              }.to change { OrphanedBlob.count }.from(0).to(OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE)
            end
          end
        end

        describe 'when a blob has a corresponding OrphanedBlob record' do
          let(:blobstore_delete) { instance_double(BlobstoreDelete) }
          let(:enqueuer) { instance_double(Jobs::Enqueuer, enqueue: nil) }
          let(:package_files) { [double(:blob, key: 'so/me/file-to-be-deleted')] }

          before do
            allow(BlobstoreDelete).to receive(:new).and_return(blobstore_delete)
            allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          end

          it 'increments the blobs dirty count' do
            OrphanedBlob.create(blob_key: 'so/me/file-to-be-deleted', dirty_count: 1, blobstore_type: 'package_blobstore')
            job.perform

            blob = OrphanedBlob.find(blob_key: 'so/me/file-to-be-deleted', blobstore_type: 'package_blobstore')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(2)
          end

          context 'when an orphaned blob exceeds the DIRTY_THRESHOLD' do
            let!(:packages_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/package-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'package_blobstore')
            end
            let!(:buildpacks_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/buildpack-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'buildpack_blobstore')
            end
            let!(:droplets_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/droplet-to-be-deleted/droplet', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'droplet_blobstore')
            end
            let!(:resources_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/resource-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'legacy_global_app_bits_cache')
            end

            it 'enqueues a BlobstoreDelete job and deletes the orphan from OrphanedBlobs' do
              job.perform

              expect(BlobstoreDelete).to have_received(:new).with('package-to-be-deleted', :package_blobstore)
              expect(BlobstoreDelete).to have_received(:new).with('buildpack-to-be-deleted', :buildpack_blobstore)
              expect(BlobstoreDelete).to have_received(:new).with('droplet-to-be-deleted/droplet', :droplet_blobstore)
              expect(BlobstoreDelete).to have_received(:new).with('resource-to-be-deleted', :legacy_global_app_bits_cache)
              expect(Jobs::Enqueuer).to have_received(:new).exactly(4).times.with(blobstore_delete, hash_including(queue: 'cc-generic'))
              expect(enqueuer).to have_received(:enqueue).exactly(4).times

              expect(packages_orphaned_blob.exists?).to be_falsey
              expect(buildpacks_orphaned_blob.exists?).to be_falsey
              expect(droplets_orphaned_blob.exists?).to be_falsey
              expect(resources_orphaned_blob.exists?).to be_falsey
            end

            it 'creates an orphaned blob audit event' do
              job.perform

              event = Event.last
              expect(event.type).to eq('blob.remove_orphan')
              expect(event.actor).to eq('system')
              expect(event.actor_type).to eq('system')
              expect(event.actor_name).to eq('system')
              expect(event.actor_username).to eq('system')
              expect(event.actee).to eq('resources/so/me/resource-to-be-deleted')
              expect(event.actee_type).to eq('blob')
            end

            context 'when the number of orphaned blobs exceeds NUMBER_OF_BLOBS_TO_DELETE' do
              let!(:orphaned_blob) do
                OrphanedBlob.create(blob_key: 'so/me/file-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'package_blobstore')
              end
              before do
                OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE.times do |i|
                  OrphanedBlob.create(blob_key: "so/me/blobstore-file-#{i}", dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD + 5, blobstore_type: 'package_blobstore')
                end
              end

              it 'only enqueues deletion jobs for NUMBER_OF_BLOBS_TO_DELETE number of blobs' do
                job.perform

                expect(BlobstoreDelete).to have_received(:new).exactly(OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE).times
              end

              it 'deletes by searching for the oldest orphaned blobs' do
                job.perform

                expect(orphaned_blob.exists?).to be_truthy
              end
            end
          end

          context 'when a previously OrphanedBlob now matches an existing resource' do
            let(:package_files) { [double(:blob, key: 're/al/real-package-blob')] }
            before do
              allow(BlobstoreDelete).to receive(:new)

              PackageModel.make(guid: 'real-package-blob')
              OrphanedBlob.create(blob_key: 're/al/real-package-blob', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, blobstore_type: 'package_blobstore')
            end

            it 'deletes the orphaned blob entry and does NOT enqueue a BlobstoreDelete job' do
              orphaned_blob = OrphanedBlob.find(blob_key: 're/al/real-package-blob', blobstore_type: 'package_blobstore')
              expect {
                job.perform
              }.to change {
                orphaned_blob.exists?
              }.from(true).to(false)
              expect(BlobstoreDelete).not_to have_received(:new).with('real-package-blob', :package_blobstore)
            end
          end
        end

        context 'when a BlobstoreError occurs' do
          before do
            allow(job).to receive(:logger).and_return(logger)
            allow(droplet_blobstore).to receive(:files).and_raise(CloudController::Blobstore::BlobstoreError.new('error'))
          end

          it 'rescues and logs the error' do
            expect { job.cleanup }.not_to raise_error
            expect(logger).to have_received(:error).with('Failed orphaned blobs cleanup job with BlobstoreError: error')
          end
        end
      end
    end
  end
end
