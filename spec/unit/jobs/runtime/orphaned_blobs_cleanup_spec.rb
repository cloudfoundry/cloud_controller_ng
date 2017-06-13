require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe OrphanedBlobsCleanup do
      subject(:job) { described_class.new }

      it { is_expected.to be_a_valid_job }

      it 'has max_attempts 1' do
        expect(job.max_attempts).to eq 1
      end

      describe '#perform' do
        let(:droplet_blobstore) { double(:blobstore_client, files: []) }
        let(:package_blobstore) { double(:blobstore_client, files: []) }
        let(:buildpack_blobstore) { double(:blobstore_client, files: []) }
        let(:legacy_resources_blobstore) { double(:blobstore_client, files: []) }

        before do
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
            let(:droplet_blobstore) { double(:blobstore_client, files: droplet_files) }
            let(:droplet_files) { [double(:blob, key: 're/al/real-droplet-blob/123')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when a blobstore file matches an existing package' do
            let!(:package) { PackageModel.make(guid: 'real-package-blob') }
            let(:package_blobstore) { double(:blobstore_client, files: package_files) }
            let(:package_files) { [double(:blob, key: 're/al/real-package-blob')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when a blobstore file matches an existing buildpack' do
            let!(:buildpack) { Buildpack.make(key: 'real-buildpack-blob') }
            let(:buildpack_blobstore) { double(:blobstore_client, files: buildpack_files) }
            let(:buildpack_files) { [double(:blob, key: 're/al/real-buildpack-blob')] }

            it 'does not mark the droplet blob as an orphan' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.count).to eq(0)
            end
          end

          context 'when the blobstore file starts with an ignored prefix' do
            let(:ignored_files) do
              [
                double(:blob, key: "#{CloudController::DependencyLocator::BUILDPACK_CACHE_DIR}/so/me/blobstore-file"),
                double(:blob, key: "#{CloudController::DependencyLocator::RESOURCE_POOL_DIR}/so/me/blobstore-file"),
              ]
            end
            let(:droplet_blobstore) { double(:blobstore_client, files: ignored_files) }

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
          let(:droplet_blobstore) { double(:blobstore_client, files: some_files) }
          let(:package_blobstore) { double(:blobstore_client, files: some_files) }
          let(:buildpack_blobstore) { double(:blobstore_client, files: some_files) }
          let(:legacy_resources_blobstore) { double(:blobstore_client, files: some_files) }

          context 'when all the blobstore buckets are different' do
            it 'should create an OrphanedBlob record for each blob in each of the blobstores' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(directory_key: 'packages').count).to eq(2)
              expect(OrphanedBlob.where(directory_key: 'droplets').count).to eq(2)
              expect(OrphanedBlob.where(directory_key: 'buildpacks').count).to eq(2)
              expect(OrphanedBlob.where(directory_key: 'resources').count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(4)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(4)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'droplets').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'packages').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'buildpacks').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'resources').dirty_count).to eq(1)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'droplets').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'packages').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'buildpacks').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'resources').dirty_count).to eq(1)
            end
          end

          context 'when all the blobstores use the same buckets as each other' do
            before do
              TestConfig.config[:packages][:app_package_directory_key]   = 'same'
              TestConfig.config[:droplets][:droplet_directory_key]       = 'same'
              TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'same'
              TestConfig.config[:resource_pool][:resource_directory_key] = 'same'
            end

            it 'it creates OrphanedBlobs for each file and marks them with the same directory_key and blobstore (as legacy_global_app_bits_cache =/)' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(directory_key: 'same').count).to eq(2)
              expect(OrphanedBlob.count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(1)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(1)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'same').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'same').dirty_count).to eq(1)
            end
          end

          context 'when some blobstores share the same bucket' do
            before do
              TestConfig.config[:packages][:app_package_directory_key]   = 'same'
              TestConfig.config[:droplets][:droplet_directory_key]       = 'same'
              TestConfig.config[:buildpacks][:buildpack_directory_key]   = 'diff'
              TestConfig.config[:resource_pool][:resource_directory_key] = 'super-diff'
            end

            it 'should create an OrphanedBlob record for each blob in each of the different blobstores (but overwrites each other based on the order in #blobstores)' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform

              expect(OrphanedBlob.where(directory_key: 'same').count).to eq(2)
              expect(OrphanedBlob.where(directory_key: 'diff').count).to eq(2)
              expect(OrphanedBlob.where(directory_key: 'super-diff').count).to eq(2)
            end

            it 'can mark an OrphanedBlob as dirty' do
              expect(OrphanedBlob.count).to eq(0)
              job.perform
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file').count).to eq(3)
              expect(OrphanedBlob.where(blob_key: 'so/me/blobstore-file2').count).to eq(3)

              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'same').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'same').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'diff').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'diff').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file', directory_key: 'super-diff').dirty_count).to eq(1)
              expect(OrphanedBlob.find(blob_key: 'so/me/blobstore-file2', directory_key: 'super-diff').dirty_count).to eq(1)
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
          let(:package_file) { [double(:blob, key: 'so/me/file-to-be-deleted')] }
          let(:package_blobstore) { double(:blobstore_client, files: package_file) }

          before do
            allow(BlobstoreDelete).to receive(:new).and_return(blobstore_delete)
            allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          end

          it 'increments the blobs dirty count' do
            OrphanedBlob.create(blob_key: 'so/me/file-to-be-deleted', dirty_count: 1, directory_key: 'packages')
            job.perform

            blob = OrphanedBlob.find(blob_key: 'so/me/file-to-be-deleted', directory_key: 'packages')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(2)
          end

          context 'when an orphaned blob exceeds the DIRTY_THRESHOLD' do
            let!(:packages_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/package-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'packages')
            end
            let!(:buildpacks_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/buildpack-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'buildpacks')
            end
            let!(:droplets_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/droplet-to-be-deleted/droplet', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'droplets')
            end
            let!(:resources_orphaned_blob) do
              OrphanedBlob.create(blob_key: 'so/me/resource-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'resources')
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
                OrphanedBlob.create(blob_key: 'so/me/file-to-be-deleted', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'bucket')
              end
              before do
                OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE.times do |i|
                  OrphanedBlob.create(blob_key: "so/me/blobstore-file-#{i}", dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD + 5, directory_key: 'bucket')
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
            let(:package_blobstore) { double(:blobstore_client, files: package_files) }
            before do
              allow(BlobstoreDelete).to receive(:new)

              PackageModel.make(guid: 'real-package-blob')
              OrphanedBlob.create(blob_key: 're/al/real-package-blob', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD, directory_key: 'packages')
            end

            it 'deletes the orphaned blob entry and does NOT enqueue a BlobstoreDelete job' do
              orphaned_blob = OrphanedBlob.find(blob_key: 're/al/real-package-blob', directory_key: 'packages')
              expect {
                job.perform
              }.to change {
                orphaned_blob.exists?
              }.from(true).to(false)
              expect(BlobstoreDelete).not_to have_received(:new).with('real-package-blob', :package_blobstore)
            end
          end
        end
      end
    end
  end
end
