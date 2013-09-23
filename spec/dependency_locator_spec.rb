require "spec_helper"
require "cloud_controller/dependency_locator"

describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.send(:new, config) }

  describe "#droplet_blobstore" do
    let(:config) do
      {
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
          cdn: cdn_settings
        },
      }
    end

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        Blobstore.should_receive(:new).with('fog_connection', 'key', nil)
        locator.droplet_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        Blobstore.should_receive(:new).with('fog_connection', 'key', cdn)
        locator.droplet_blobstore
      end
    end
  end

  describe "#buildpack_cache_blobstore" do
    let(:config) do
      {
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        Blobstore.should_receive(:new).with('fog_connection', 'key', nil, "buildpack_cache")
        locator.buildpack_cache_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        Blobstore.should_receive(:new).with('fog_connection', 'key', cdn, "buildpack_cache")
        locator.buildpack_cache_blobstore
      end
    end
  end

  describe "#package_blobstore" do
    let(:config) do
      {
        packages: {
          fog_connection: 'fog_connection',
          app_package_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        Blobstore.should_receive(:new).with('fog_connection', 'key', nil)
        locator.package_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        Blobstore.should_receive(:new).with('fog_connection', 'key', cdn)
        locator.package_blobstore
      end
    end
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

    context "when cdn is not configured" do
      let(:cdn_settings) { nil }

      it "creates blob stores without the CDN" do
        Blobstore.should_receive(:new).with('fog_connection', 'key', nil)
        locator.global_app_bits_cache
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        Blobstore.should_receive(:new).with('fog_connection', 'key', cdn)
        locator.global_app_bits_cache
      end
    end
  end

  describe "blobstore_url_generator" do
    let(:my_config) do
      {
        bind_address: "bind.address",
        port: 8282,
        staging: {
          auth: {
            user: "username",
            password: "password",
          }
        }
      }
    end

    before do
      config_override(my_config)
    end

    it "creates blobstore_url_generator with the host, port, and blobstores" do
      connection_options = {
        blobstore_host: "bind.address",
        blobstore_port: 8282,
        user: "username",
        password: "password"
      }
      CloudController::BlobstoreUrlGenerator.should_receive(:new).with(hash_including(connection_options), anything, anything, anything)
      locator.blobstore_url_generator
    end
  end
end