require 'spec_helper'

RSpec.describe 'Legacy Jobs' do
  describe ::AppBitsPackerJob do
    subject { ::AppBitsPackerJob.new('app-guid', 'path/to/compressed/file', 'the-fingerprint') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::AppBitsPacker) }
  end

  describe ::BlobstoreDelete do
    subject { ::BlobstoreDelete.new('key', 'blobstore-name') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreDelete) }
  end

  describe ::BlobstoreUpload do
    subject { ::BlobstoreUpload.new('/a/b', 'blobstore_key', 'blobstore_name') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreUpload) }
  end

  describe ::DropletDeletionJob do
    subject { ::DropletDeletionJob.new('new-key', 'old-key') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::DropletDeletion) }
  end

  describe ::DropletUploadJob do
    subject { ::DropletUploadJob.new('/a/b', 'app_id') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::DropletUpload) }
  end

  describe ::ModelDeletionJob do
    subject { ::ModelDeletionJob.new(VCAP::CloudController::Space, 'space-guid') }
    it { is_expected.to be_a(VCAP::CloudController::Jobs::Runtime::ModelDeletion) }
  end
end
