require "spec_helper"

describe "Legacy Jobs" do
  describe ::AppBitsPackerJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::AppBitsPacker) }
  end

  describe ::BlobstoreDelete do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreDelete) }
  end

  describe ::BlobstoreUpload do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::BlobstoreUpload) }
  end

  describe ::DropletDeletionJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::DropletDeletion) }
  end
end
