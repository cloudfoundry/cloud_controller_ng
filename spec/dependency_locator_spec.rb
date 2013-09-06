require "spec_helper"
require "cloud_controller/dependency_locator"

describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.send(:new, config) }

  shared_examples "creates a blob store" do |message|
    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        BlobStore.should_receive(:new).with('fog_connection', 'key', nil)
        locator.send(message)
      end
    end

    context "when cdn is configured for droplet blob store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { {uri: cdn_host, key_pair_id: 'key_pair'} }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        BlobStore.should_receive(:new).with('fog_connection', 'key', cdn)
        locator.send(message)
      end
    end
  end

  describe "#droplet_blob_store" do
    let(:config) do
      {
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    include_examples "creates a blob store", :droplet_blob_store
  end

  describe "#package_blob_store" do
    let(:config) do
      {
        packages: {
          fog_connection: 'fog_connection',
          app_package_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    include_examples "creates a blob store", :package_blob_store
  end

  describe "#global_app_bits_cache" do
    let(:config) do
      {
        resource_pool: {
          fog_connection: 'fog_connection',
          resource_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    include_examples "creates a blob store", :global_app_bits_cache
  end
end
