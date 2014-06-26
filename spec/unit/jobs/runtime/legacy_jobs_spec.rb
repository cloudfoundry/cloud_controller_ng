require "spec_helper"

describe "Legacy Jobs" do
  describe ::AppBitsPackerJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::AppBitsPacker) }
  end

  describe ::BlobstoreDelete do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreDelete) }
  end

  describe ::BlobstoreUpload do
    subject {::BlobstoreUpload.new('/a/b', 'blobstore_key', 'blobstore_name')}
    it { should be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreUpload) }
  end

  describe ::DropletDeletionJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::DropletDeletion) }
  end

  describe ::DropletUploadJob do
    subject {::DropletUploadJob.new('/a/b', 'app_id')}
    it { should be_a(VCAP::CloudController::Jobs::Runtime::DropletUpload) }
  end

  describe ::ModelDeletionJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::ModelDeletion) }
  end
end
