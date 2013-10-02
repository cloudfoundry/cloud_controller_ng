require "spec_helper"

describe AppBitsPackerJob do
  describe "#perform" do
    let(:app) { double(:app) }
    let(:uploaded_path) { "tmp/uploaded.zip" }
    let(:fingerprints) { double(:fingerprints) }
    let(:package_blobstore) { double(:package_blobstore) }
    let(:global_app_bits_cache) { double(:global_app_bits_cache) }
    let(:tmpdir) { "/tmp/special_temp" }
    let(:max_droplet_size) { 256 }

    before do
      config_override({:directories => {:tmpdir => tmpdir}, :packages => config[:packages].merge(:max_droplet_size => max_droplet_size)})

      FingerprintsCollection.stub(:new) { fingerprints }
      VCAP::CloudController::App.stub(:find) { app }
      AppBitsPacker.stub(:new) { double(:packer, perform: "done") }
    end

    subject(:job) {
      AppBitsPackerJob.new("app_guid", uploaded_path, [:fingerprints]) }

    it "finds the app from the guid" do
      VCAP::CloudController::App.should_receive(:find).with(guid: "app_guid")
      job.perform
    end

    it "creates blob stores" do
      CloudController::DependencyLocator.instance.should_receive(:package_blobstore)
      CloudController::DependencyLocator.instance.should_receive(:global_app_bits_cache)
      job.perform
    end

    it "creates an app bit packer and performs" do
      CloudController::DependencyLocator.instance.should_receive(:package_blobstore).and_return(package_blobstore)
      CloudController::DependencyLocator.instance.should_receive(:global_app_bits_cache).and_return(global_app_bits_cache)

      packer = double
      AppBitsPacker.should_receive(:new).with(package_blobstore, global_app_bits_cache, max_droplet_size, tmpdir).and_return(packer)
      packer.should_receive(:perform).with(app, uploaded_path, fingerprints)
      job.perform
    end

    it "deletes the file after it is done" do
      FileUtils.should_receive(:rm_f).with(uploaded_path)
      job.perform
    end

    context "when there is no package uploaded" do
      let(:uploaded_path) { nil }

      it "doesn't try to remove the file" do
        FileUtils.should_not_receive(:rm_f)
        job.perform
      end
    end
  end
end
