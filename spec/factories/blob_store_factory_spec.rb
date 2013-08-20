require "spec_helper"
require "factories/blob_store_factory"

describe BlobStoreFactory do
  describe "#get_package_blob_store" do
    before do
      Settings.stub_chain(:packages).and_return(
        mock(:packages,
          fog_connection: 'fog_connection',
          app_package_directory_key: 'key'
        )
      )
      Settings.stub_chain(:packages, :cdn).and_return(cdn_settings)
    end

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        BlobStore.should_receive(:new).with('fog_connection', 'key', nil)
        BlobStoreFactory.get_package_blob_store
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { mock(:cdn_settings, uri: cdn_host, key_pair_id: 'key_pair') }
      let(:cdn) { mock(:cdn) }

      before do
        Settings.stub_chain(:packages, :cdn).and_return(
          mock(:cdn_config, uri: cdn_host, key_pair_id: 'key_pair')
        )
      end

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        BlobStore.should_receive(:new).with('fog_connection', 'key', cdn)
        BlobStoreFactory.get_package_blob_store
      end
    end
  end

  describe "#get_app_bit_cache" do
    before do
      Settings.stub_chain(:resource_pool).and_return(
        mock(:resource_pool,
          fog_connection: 'fog_connection',
          resource_directory_key: 'key'
        )
      )
      Settings.stub_chain(:resource_pool, :cdn).and_return(cdn_settings)
    end

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        BlobStore.should_receive(:new).with('fog_connection', 'key', nil)
        BlobStoreFactory.get_app_bit_cache
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { mock(:cdn_settings, uri: cdn_host, key_pair_id: 'key_pair') }
      let(:cdn) { mock(:cdn) }

      before do
        Settings.stub_chain(:resource_pool, :cdn).and_return(
          mock(:cdn_config, uri: cdn_host, key_pair_id: 'key_pair')
        )
      end

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        BlobStore.should_receive(:new).with('fog_connection', 'key', cdn)
        BlobStoreFactory.get_app_bit_cache
      end
    end
  end
end