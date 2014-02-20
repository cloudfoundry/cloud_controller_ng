require "spec_helper"
require "cloud_controller/dependency_locator"

describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.send(:new, config) }

  describe "#health_manager_client" do
    context "when hm9000 is noop" do
      let(:config) {{:hm9000_noop => true}}

      it "should return the old hm client" do
        expect(locator.health_manager_client).to be_an_instance_of(VCAP::CloudController::HealthManagerClient)
      end
    end

    context "when hm9000 is not noop" do
      let(:config) {{:hm9000_noop => false}}

      it "should return the shiny new hm9000 client" do
        expect(locator.health_manager_client).to be_an_instance_of(VCAP::CloudController::HM9000Client)
      end
    end
  end

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
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', nil)
        locator.droplet_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', cdn)
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
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', nil, "buildpack_cache")
        locator.buildpack_cache_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', cdn, "buildpack_cache")
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
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', nil)
        locator.package_blobstore
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', cdn)
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
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', nil)
        locator.global_app_bits_cache
      end
    end

    context "when cdn is configured for package blog store" do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it "creates the blob stores with CDNs if configured" do
        Cdn.should_receive(:new).with(cdn_host).and_return(cdn)
        CloudController::Blobstore::Client.should_receive(:new).with('fog_connection', 'key', cdn)
        locator.global_app_bits_cache
      end
    end
  end

  describe "#blobstore_url_generator" do
    let(:my_config) do
      {
        external_host: "external.host",
        external_port: 8282,
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
        blobstore_host: "external.host",
        blobstore_port: 8282,
        user: "username",
        password: "password"
      }
      CloudController::Blobstore::UrlGenerator.should_receive(:new).
        with(hash_including(connection_options),
             instance_of(CloudController::Blobstore::Client),
             instance_of(CloudController::Blobstore::Client),
             instance_of(CloudController::Blobstore::Client),
             instance_of(CloudController::Blobstore::Client)
      )
      locator.blobstore_url_generator
    end
  end

  describe "#app_event_repository" do
    subject { locator.app_event_repository }

    it { should be_a(VCAP::CloudController::Repositories::Runtime::AppEventRepository) }

    it "memoizes the instance" do
      expect(locator.app_event_repository).to eq(locator.app_event_repository)
    end
  end

  describe "#space_event_repository" do
    subject { locator.space_event_repository }

    it { should be_a(VCAP::CloudController::Repositories::Runtime::SpaceEventRepository) }
  end

  describe "#object_renderer" do
    it "returns paginated collection renderer configured via config" do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opts = {max_inline_relations_depth: 100_002}

      config_override(renderer: opts)

      renderer = double('renderer')
      VCAP::CloudController::RestController::ObjectRenderer.
        should_receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.object_renderer).to eq(renderer)
    end
  end

  describe "#paginated_collection_renderer" do
    it "returns paginated collection renderer configured via config" do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opts = {
        max_results_per_page: 100_000,
        default_results_per_page: 100_001,
        max_inline_relations_depth: 100_002,
      }

      config_override(renderer: opts)

      renderer = double('renderer')
      VCAP::CloudController::RestController::PaginatedCollectionRenderer.
        should_receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.paginated_collection_renderer).to eq(renderer)
    end
  end

  describe "#entity_only_paginated_collection_renderer" do
    it "returns paginated collection renderer configured via config" do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::EntityOnlyPreloadedObjectSerializer)
      opts = {
        max_results_per_page: 100_000,
        default_results_per_page: 100_001,
        max_inline_relations_depth: 100_002,
      }

      config_override(renderer: opts)

      renderer = double('renderer')
      VCAP::CloudController::RestController::PaginatedCollectionRenderer.
        should_receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.entity_only_paginated_collection_renderer).to eq(renderer)
    end
  end
end
