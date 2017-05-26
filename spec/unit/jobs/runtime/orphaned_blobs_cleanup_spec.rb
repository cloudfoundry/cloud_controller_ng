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
        let(:droplet_blobstore_files) do
          [
            double(:blob, key: 'so/me/blobstore-file'),
            double(:blob, key: 'so/me/blobstore-file2'),
          ]
        end
        let(:droplet_blobstore) { double(:blobstore_client, files: droplet_blobstore_files) }

        before do
          TestConfig.config[:packages][:app_package_directory_key] = 'bucket'
          TestConfig.config[:droplets][:droplet_directory_key] = 'bucket'
          TestConfig.config[:buildpacks][:buildpack_directory_key] = 'bucket'

          allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(droplet_blobstore)
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(droplet_blobstore)
          allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(droplet_blobstore)
        end

        it 'can mark an orphaned droplet blob as dirty' do
          expect(OrphanedBlob.count).to eq(0)
          job.perform

          first_blob = OrphanedBlob.find(blob_key: 'so/me/blobstore-file')
          expect(first_blob).to_not be_nil
          expect(first_blob.dirty_count).to eq(1)

          second_blob = OrphanedBlob.find(blob_key: 'so/me/blobstore-file2')
          expect(second_blob).to_not be_nil
          expect(second_blob.dirty_count).to eq(1)
        end

        context 'when a blobstore file matches an existing droplet' do
          let!(:droplet) { DropletModel.make(guid: 'real-droplet-blob', droplet_hash: '123') }
          let(:droplet_blobstore_files) { [double(:blob, key: 're/al/real-droplet-blob/123')] }

          it 'does not mark the droplet blob as an orphan' do
            expect(OrphanedBlob.count).to eq(0)
            job.perform
            expect(OrphanedBlob.count).to eq(0)
          end
        end

        context 'when a blobstore file matches an existing package' do
          let!(:package) { PackageModel.make(guid: 'real-package-blob') }
          let(:droplet_blobstore_files) { [double(:blob, key: 're/al/real-package-blob')] }

          it 'does not mark the droplet blob as an orphan' do
            expect(OrphanedBlob.count).to eq(0)
            job.perform
            expect(OrphanedBlob.count).to eq(0)
          end
        end

        context 'when a blobstore file matches an existing buildpack' do
          let!(:buildpack) { Buildpack.make(key: 'real-buildpack-blob') }
          let(:droplet_blobstore_files) { [double(:blob, key: 're/al/real-buildpack-blob')] }

          it 'does not mark the droplet blob as an orphan' do
            expect(OrphanedBlob.count).to eq(0)
            job.perform
            expect(OrphanedBlob.count).to eq(0)
          end
        end

        context 'when the blobstore file starts with an ignored prefix' do
          let(:droplet_blobstore_files) do
            [
              double(:blob, key: "#{CloudController::DependencyLocator::BUILDPACK_CACHE_DIR}/so/me/blobstore-file"),
              double(:blob, key: "#{CloudController::DependencyLocator::RESOURCE_POOL_DIR}/so/me/blobstore-file"),
            ]
          end

          it 'will never mark the blob as an orphan' do
            expect {
              job.perform
            }.to_not change { OrphanedBlob.count }
          end
        end

        context 'when a blob is already marked as an orphaned blob' do
          before { OrphanedBlob.create(blob_key: 'so/me/blobstore-file', dirty_count: 1) }

          it 'increments the blobs dirty count' do
            job.perform

            blob = OrphanedBlob.find(blob_key: 'so/me/blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(2)
          end
        end

        context 'when an orphaned blob exceeds the DIRTY_THRESHOLD' do
          let!(:orphaned_blob) { OrphanedBlob.create(blob_key: 'so/me/blobstore-file', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD) }
          let(:blobstore_delete) { instance_double(BlobstoreDelete) }
          let(:enqueuer) { instance_double(Jobs::Enqueuer, enqueue: nil) }

          before do
            allow(BlobstoreDelete).to receive(:new).and_return(blobstore_delete)
            allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          end

          it 'increments the blobs dirty count' do
            job.perform

            expect(BlobstoreDelete).to have_received(:new).with('blobstore-file', :droplet_blobstore)
            expect(Jobs::Enqueuer).to have_received(:new).with(blobstore_delete, hash_including(queue: 'cc-generic'))
            expect(enqueuer).to have_received(:enqueue)

            expect(orphaned_blob.exists?).to be_falsey
          end

          context 'when the number of orphaned blobs exceeds NUMBER_OF_BLOBS_TO_DELETE' do
            let(:droplet_blobstore_files) do
              files = [double(:blob, key: 'so/me/blobstore-file')]
              (OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE).times do |i|
                files << double(:blob, key: "so/me/blobstore-file-#{i}")
              end
              files
            end

            before do
              (OrphanedBlobsCleanup::NUMBER_OF_BLOBS_TO_DELETE).times do |i|
                OrphanedBlob.create(blob_key: "so/me/blobstore-file-#{i}", dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD + 5)
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

        context 'when an existing resource matches against an orphaned blob' do
          let!(:droplet) { DropletModel.make(guid: 'real-droplet-blob') }
          let!(:orphaned_blob) { OrphanedBlob.create(blob_key: 're/al/real-droplet-blob', dirty_count: OrphanedBlobsCleanup::DIRTY_THRESHOLD) }

          let(:droplet_blobstore_files) { [double(:blob, key: 're/al/real-droplet-blob')] }

          it 'deletes the orphaned blob entry' do
            expect {
              job.perform
            }.to change {
              orphaned_blob.exists?
            }.from(true).to(false)
          end
        end

        context 'when each blobstore is in its own directory' do
          let(:package_blobstore) { double(:blobstore_client, files: package_blobstore_files) }
          let(:buildpack_blobstore) { double(:blobstore_client, files: buildpack_blobstore_files) }

          let(:droplet_blobstore_files) { [double(:blob, key: 'so/me/droplet-blobstore-file')] }
          let(:package_blobstore_files) { [double(:blob, key: 'so/me/package-blobstore-file')] }
          let(:buildpack_blobstore_files) { [double(:blob, key: 'so/me/buildpack-blobstore-file')] }

          before do
            TestConfig.config[:packages][:app_package_directory_key] = 'bucket-2'
            TestConfig.config[:buildpacks][:buildpack_directory_key] = 'bucket-4'

            allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
            allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)
          end

          it 'can mark an orphaned droplet blob as dirty' do
            expect(OrphanedBlob.count).to eq(0)
            job.perform

            blob = OrphanedBlob.find(blob_key: 'so/me/droplet-blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(1)

            blob = OrphanedBlob.find(blob_key: 'so/me/package-blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(1)

            blob = OrphanedBlob.find(blob_key: 'so/me/buildpack-blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(1)
          end
        end

        context 'when there is some overlap for which directory each blobstore uses' do
          let(:droplet_blobstore_files) { [double(:blob, key: 'so/me/shared-blobstore-file')] }

          let(:buildpack_blobstore) { double(:blobstore_client, files: buildpack_blobstore_files) }
          let(:buildpack_blobstore_files) { [double(:blob, key: 'so/me/buildpack-blobstore-file')] }

          before do
            TestConfig.config[:buildpacks][:buildpack_directory_key] = 'bucket-4'

            allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)
          end

          it 'can mark an orphaned droplet blob as dirty' do
            expect(OrphanedBlob.count).to eq(0)
            job.perform

            blob = OrphanedBlob.find(blob_key: 'so/me/shared-blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(1)

            blob = OrphanedBlob.find(blob_key: 'so/me/buildpack-blobstore-file')
            expect(blob).to_not be_nil
            expect(blob.dirty_count).to eq(1)
          end
        end
      end
    end
  end
end
