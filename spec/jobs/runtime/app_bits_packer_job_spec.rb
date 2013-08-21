require "spec_helper"

describe AppBitsPackerJob do
  describe "#perform" do
    let(:app) { double(:app) }
    let(:uploaded_path) { "tmp/uploaded.zip" }
    let(:fingerprints) { double(:fingerprints) }

    before do
      FingerprintsCollection.stub(:new) { fingerprints }
      VCAP::CloudController::Models::App.stub(:find) { app }
      AppBitsPacker.stub(:new) { double(:packer, perform: "done") }
    end

    subject(:job) {
      AppBitsPackerJob.new("app_guid", uploaded_path, [:fingerprints]) }

    it "finds the app from the guid" do
      VCAP::CloudController::Models::App.should_receive(:find).with(guid: "app_guid")
      job.perform
    end

    it "creates blob stores" do
      CloudController::DependencyLocator.instance.should_receive(:package_blob_store)
      CloudController::DependencyLocator.instance.should_receive(:global_app_bits_cache)
      job.perform
    end

    it "creates an app bit packer and performs" do
      packer = double
      AppBitsPacker.should_receive(:new).and_return(packer)
      packer.should_receive(:perform).with(app, uploaded_path, fingerprints)
      job.perform
    end
  end
end
