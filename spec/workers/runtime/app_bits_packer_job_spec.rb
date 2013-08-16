require "spec_helper"

describe AppBitsPackerJob do
  describe "#perform" do
    let(:app) { mock(:app) }
    let(:uploaded_path) { "tmp/uploaded.zip" }
    let(:fingerprints) { mock(:fingerprints) }

    before do
      Cdn.stub(:new) { mock(:cdn) }
      BlobStore.stub(:new) { mock(:blob_store) }
      FingerprintsCollection.stub(:new) { fingerprints}
      VCAP::CloudController::Models::App.stub(:find) { app }
      AppBitsPacker.stub(:new) { mock(:packer, perform: "done") }
    end

    subject(:job) {
    AppBitsPackerJob.new("app_guid", uploaded_path, [:fingerprints])}

    it "finds the app from the guid" do
      VCAP::CloudController::Models::App.should_receive(:find).with(guid: "app_guid")
      job.perform
    end

    it "creates blob stores" do
      BlobStore.should_receive(:new).with(
        Settings.resource_pool.fog_connection,
        Settings.resource_pool.resource_directory_key,
        nil)
      BlobStore.should_receive(:new).with(
        Settings.packages.fog_connection,
        Settings.packages.app_package_directory_key,
        nil)

      job.perform
    end

    it "creates an app bit packer and performs" do
      packer = mock
      AppBitsPacker.should_receive(:new).and_return(packer)
      packer.should_receive(:perform).with(app, uploaded_path, fingerprints)
      job.perform
    end

    context "when cdn is configured for app bit cache blob store" do
      let(:cdn) { mock(:cdn)}
      let(:cdn_host) { 'http://crazy_cdn.com' }

      before do
        Settings.stub_chain(:resource_pool).and_return(
          mock(:resource_pool,
            fog_connection: 'fog_connection',
            resource_directory_key: 'key'
          )
        )

        Settings.stub_chain(:resource_pool, :cdn).and_return(
          mock(:cd_config, uri: cdn_host, key_pair_id: 'key_pair')
        )
      end

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        BlobStore.should_receive(:new).with(
          Settings.resource_pool.fog_connection,
          Settings.resource_pool.resource_directory_key,
          cdn)
        job.perform
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn) { mock(:cdn)}
      let(:cdn_host) { 'http://crazy_cdn.com' }

      before do
        Settings.stub_chain(:packages).and_return(
          mock(:packages,
            fog_connection: 'fog_connection',
            app_package_directory_key: 'key'
          )
        )

        Settings.stub_chain(:packages, :cdn).and_return(
          mock(:cdn_config, uri: cdn_host, key_pair_id: 'key_pair')
        )
      end

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        BlobStore.should_receive(:new).with(
          Settings.packages.fog_connection,
          Settings.packages.app_package_directory_key,
          cdn)
        job.perform
      end
    end
  end
end