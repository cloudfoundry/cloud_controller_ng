require "spec_helper"

describe AppBitsPackerJob do
  describe "#perform" do
    let(:app) { mock(:app) }
    let(:uploaded_path) { "tmp/uploaded.zip" }
    let(:fingerprints) { mock(:fingerprints) }

    before do
      BlobStoreFactory.stub(:new) { mock(:blob_store) }
      FingerprintsCollection.stub(:new) { fingerprints }
      VCAP::CloudController::Models::App.stub(:find) { app }
      AppBitsPacker.stub(:new) { mock(:packer, perform: "done") }
    end

    subject(:job) {
      AppBitsPackerJob.new("app_guid", uploaded_path, [:fingerprints]) }

    it "finds the app from the guid" do
      VCAP::CloudController::Models::App.should_receive(:find).with(guid: "app_guid")
      job.perform
    end

    it "creates blob stores" do
      BlobStoreFactory.should_receive(:get_package_blob_store)
      BlobStoreFactory.should_receive(:get_app_bit_cache)
      job.perform
    end

    it "creates an app bit packer and performs" do
      packer = mock
      AppBitsPacker.should_receive(:new).and_return(packer)
      packer.should_receive(:perform).with(app, uploaded_path, fingerprints)
      job.perform
    end
  end
end
