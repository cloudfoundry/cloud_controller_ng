require 'spec_helper'
require 'cloud_controller/dependency_locator'

describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.instance }

  let(:config) { TestConfig.config }

  before { locator.config = config }

  describe '#health_manager_client' do
    it 'should return the hm9000 client' do
      expect(locator.health_manager_client).to be_an_instance_of(VCAP::CloudController::Dea::HM9000::Client)
    end
  end

  describe '#droplet_blobstore' do
    let(:config) do
      {
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
          cdn: cdn_settings
        },
      }
    end

    context 'when cdn is not configured' do
      let(:cdn_settings) { nil }

      it 'creates blob stores without the CDN' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil)
        locator.droplet_blobstore
      end
    end

    context 'when cdn is configured for package blog store' do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it 'creates the blob stores with CDNs if configured' do
        expect(CloudController::Blobstore::Cdn).to receive(:new).with(cdn_host).and_return(cdn)
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', cdn)
        locator.droplet_blobstore
      end
    end
  end

  describe '#buildpack_cache_blobstore' do
    let(:config) do
      {
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    context 'when cdn is not configured' do
      let(:cdn_settings) { nil }

      it 'creates blob stores without the CDN' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil, 'buildpack_cache')
        locator.buildpack_cache_blobstore
      end
    end

    context 'when cdn is configured for package blog store' do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it 'creates the blob stores with CDNs if configured' do
        expect(CloudController::Blobstore::Cdn).to receive(:new).with(cdn_host).and_return(cdn)
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', cdn, 'buildpack_cache')
        locator.buildpack_cache_blobstore
      end
    end
  end

  describe '#package_blobstore' do
    let(:config) do
      {
        packages: {
          fog_connection: 'fog_connection',
          app_package_directory_key: 'key',
          cdn: cdn_settings
        }
      }
    end

    context 'when cdn is not configured' do
      let(:cdn_settings) { nil }

      it 'creates blob stores without the CDN' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil)
        locator.package_blobstore
      end
    end

    context 'when cdn is configured for package blog store' do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }

      it 'creates the blob stores with CDNs if configured' do
        expect(CloudController::Blobstore::Cdn).to receive(:new).with(cdn_host).and_return(cdn)
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', cdn)
        locator.package_blobstore
      end
    end
  end

  describe '#global_app_bits_cache' do
    let(:config) do
      {
        resource_pool: {
          fog_connection: 'fog_connection',
          resource_directory_key: 'key',
          cdn: cdn_settings,
          minimum_size: min_file_size,
          maximum_size: max_file_size
        }
      }
    end

    context 'when cdn is not configured' do
      let(:cdn_settings) { nil }
      let(:min_file_size) { nil }
      let(:max_file_size) { nil }

      it 'creates blob stores without the CDN' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil, nil, nil, nil)
        locator.global_app_bits_cache
      end
    end

    context 'when file size limits are not configured' do
      let(:cdn_settings) { nil }
      let(:min_file_size) { nil }
      let(:max_file_size) { nil }

      it 'creates blob stores without file size limits' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil, nil, nil, nil)
        locator.global_app_bits_cache
      end
    end

    context 'when file size limits are configured for package blobstore' do
      let(:cdn_settings) { nil }
      let(:min_file_size) { 1024 }
      let(:max_file_size) { 512 * 1024 * 1024 }

      it 'creates the blob stores with file size limits if configured' do
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', nil, nil, min_file_size, max_file_size)
        locator.global_app_bits_cache
      end
    end

    context 'when cdn is configured for package blog store' do
      let(:cdn_host) { 'http://crazy_cdn.com' }
      let(:cdn_settings) { { uri: cdn_host, key_pair_id: 'key_pair' } }
      let(:cdn) { double(:cdn) }
      let(:min_file_size) { nil }
      let(:max_file_size) { nil }

      it 'creates the blob stores with CDNs if configured' do
        expect(CloudController::Blobstore::Cdn).to receive(:new).with(cdn_host).and_return(cdn)
        expect(CloudController::Blobstore::Client).to receive(:new).with('fog_connection', 'key', cdn, nil, nil, nil)
        locator.global_app_bits_cache
      end
    end
  end

  describe '#blobstore_url_generator' do
    let(:internal_service_hostname) { 'internal.service.hostname' }
    let(:my_config) do
      {
        internal_service_hostname: internal_service_hostname,
        external_host: 'external.host',
        external_port: 8282,
        staging: {
          auth: {
            user: 'username',
            password: 'password',
          }
        }
      }
    end

    before do
      TestConfig.override(my_config)
    end

    context 'when called without an argument' do
      it 'creates blobstore_url_generator with the external host, port, and blobstores' do
        connection_options = {
          blobstore_host: 'external.host',
          blobstore_port: 8282,
          user: 'username',
          password: 'password'
        }
        expect(CloudController::Blobstore::UrlGenerator).to receive(:new).
            with(hash_including(connection_options),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client)
            )
        locator.blobstore_url_generator
      end
    end

    context 'when the internal_service_hostname is nil' do
      let(:internal_service_hostname) { nil }

      it 'creates blobstore_url_generator with the external host, port, and blobstores' do
        connection_options = {
          blobstore_host: 'external.host',
          blobstore_port: 8282,
          user: 'username',
          password: 'password'
        }
        expect(CloudController::Blobstore::UrlGenerator).to receive(:new).
            with(hash_including(connection_options),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client),
              instance_of(CloudController::Blobstore::Client)
            ).twice
        locator.blobstore_url_generator(true)
        locator.blobstore_url_generator(false)
      end
    end

    context 'when the internal_service_hostname is not nil' do
      let(:internal_service_hostname) { 'internal.service.hostname' }

      context 'and use_service_dns is true' do
        it 'creates blobstore_url_generator with the internal service hostname, port, and blobstores' do
          connection_options = {
            blobstore_host: 'internal.service.hostname',
            blobstore_port: 8282,
            user: 'username',
            password: 'password'
          }
          expect(CloudController::Blobstore::UrlGenerator).to receive(:new).
              with(hash_including(connection_options),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client)
              )
          locator.blobstore_url_generator(true)
        end
      end

      context 'and use_service_dns is false' do
        it 'creates blobstore_url_generator with the external host, port, and blobstores' do
          connection_options = {
            blobstore_host: 'external.host',
            blobstore_port: 8282,
            user: 'username',
            password: 'password'
          }
          expect(CloudController::Blobstore::UrlGenerator).to receive(:new).
              with(hash_including(connection_options),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client),
                instance_of(CloudController::Blobstore::Client)
              )
          locator.blobstore_url_generator(false)
        end
      end
    end
  end

  describe '#app_event_repository' do
    subject { locator.app_event_repository }

    it { is_expected.to be_a(VCAP::CloudController::Repositories::Runtime::AppEventRepository) }

    it 'memoizes the instance' do
      expect(locator.app_event_repository).to eq(locator.app_event_repository)
    end
  end

  describe '#space_event_repository' do
    subject { locator.space_event_repository }

    it { is_expected.to be_a(VCAP::CloudController::Repositories::Runtime::SpaceEventRepository) }
  end

  describe '#object_renderer' do
    it 'returns paginated collection renderer configured via config' do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opts = { max_inline_relations_depth: 100_002 }

      TestConfig.override(renderer: opts)

      renderer = double('renderer')
      expect(VCAP::CloudController::RestController::ObjectRenderer).
        to receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.object_renderer).to eq(renderer)
    end
  end

  describe '#paginated_collection_renderer' do
    it 'returns paginated collection renderer configured via config' do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opts = {
        max_results_per_page: 100_000,
        default_results_per_page: 100_001,
        max_inline_relations_depth: 100_002,
        collection_transformer: nil
      }

      TestConfig.override(renderer: opts)

      renderer = double('renderer')
      expect(VCAP::CloudController::RestController::PaginatedCollectionRenderer).
        to receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.paginated_collection_renderer).to eq(renderer)
    end
  end

  describe '#large_paginated_collection_renderer' do
    it 'returns paginated collection renderer configured via config with a max of 10,000 results per page' do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opts = {
        max_results_per_page: 10,
        default_results_per_page: 100_001,
        max_inline_relations_depth: 100_002,
        collection_transformer: nil
      }

      TestConfig.override(renderer: opts)

      renderer = double('renderer')
      expect(VCAP::CloudController::RestController::PaginatedCollectionRenderer).
        to receive(:new).
        with(eager_loader, serializer, opts.merge(max_results_per_page: 10_000)).
        and_return(renderer)

      expect(locator.large_paginated_collection_renderer).to eq(renderer)
    end
  end

  describe '#entity_only_paginated_collection_renderer' do
    it 'returns paginated collection renderer configured via config' do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::EntityOnlyPreloadedObjectSerializer)
      opts = {
        max_results_per_page: 100_000,
        default_results_per_page: 100_001,
        max_inline_relations_depth: 100_002,
        collection_transformer: nil
      }

      TestConfig.override(renderer: opts)

      renderer = double('renderer')
      expect(VCAP::CloudController::RestController::PaginatedCollectionRenderer).
        to receive(:new).
        with(eager_loader, serializer, opts).
        and_return(renderer)

      expect(locator.entity_only_paginated_collection_renderer).to eq(renderer)
    end
  end

  describe '#username_populating_collection_renderer' do
    it 'returns paginated collection renderer with a UsernamePopulator transformer' do
      renderer = locator.username_populating_collection_renderer
      expect(renderer.collection_transformer).to be_a(VCAP::CloudController::UsernamePopulator)
    end

    it 'uses the username_lookup_uaa_client for the populator' do
      uaa_client = double('uaa client')
      expect(locator).to receive(:username_lookup_uaa_client).and_return(uaa_client)
      renderer = locator.username_populating_collection_renderer
      expect(renderer.collection_transformer.uaa_client).to eq(uaa_client)
    end
  end

  describe '#quota_usage_populating_renderer' do
    it 'returns collection renderer with a QuotaUsagePopulator transformer' do
      renderer = locator.quota_usage_populating_renderer
      expect(renderer.transformer).to be_a(VCAP::CloudController::QuotaUsagePopulator)
    end

    it 'returns object renderer' do
      expect(locator.quota_usage_populating_renderer).to be_an_instance_of(VCAP::CloudController::RestController::ObjectRenderer)
    end

    it 'returns object renderer configured via config' do
      eager_loader = instance_of(VCAP::CloudController::RestController::SecureEagerLoader)
      serializer = instance_of(VCAP::CloudController::RestController::PreloadedObjectSerializer)
      opt = {
        max_inline_relations_depth: 100_002,
      }

      TestConfig.override(renderer: opt)

      expect(VCAP::CloudController::RestController::ObjectRenderer).
        to receive(:new).
        with(eager_loader, serializer, an_instance_of(Hash)) do |loader, ser, opts|
          expect(opts[:max_inline_relations_depth]).to eql(100_002)
          expect(opts[:transformer]).to be_an_instance_of(VCAP::CloudController::QuotaUsagePopulator)
        end

      locator.quota_usage_populating_renderer
    end
  end

  describe '#username_lookup_uaa_client' do
    it 'returns a uaa client with credentials for lookuping up usernames' do
      uaa_client = locator.username_lookup_uaa_client
      expect(uaa_client.client_id).to eq(config[:cloud_controller_username_lookup_client_name])
      expect(uaa_client.secret).to eq(config[:cloud_controller_username_lookup_client_secret])
      expect(uaa_client.uaa_target).to eq(config[:uaa][:url])
    end

    context 'when skip_cert_verify is true in the config' do
      before { TestConfig.override(skip_cert_verify: true) }

      it 'skips ssl validation to uaa' do
        uaa_client = locator.username_lookup_uaa_client
        expect(uaa_client.options[:skip_ssl_validation]).to be true
      end
    end
  end

  describe '#missing_blob_handler' do
    it 'returns the correct handler' do
      handler = double('a missing blob handler')
      expect(CloudController::BlobSender::MissingBlobHandler).to receive(:new).and_return(handler)
      expect(locator.missing_blob_handler).to eq(handler)
    end
  end

  describe '#blob_sender' do
    let(:sender) { double('sender') }
    it 'returns the correct sender when using ngx' do
      config[:nginx][:use_nginx] = true
      expect(CloudController::BlobSender::NginxLocalBlobSender).to receive(:new).and_return(sender)
      expect(locator.blob_sender).to eq(sender)
    end

    it 'returns the correct sender when not using ngx' do
      config[:nginx][:use_nginx] = false
      expect(CloudController::BlobSender::DefaultLocalBlobSender).to receive(:new).and_return(sender)
      expect(locator.blob_sender).to eq(sender)
    end
  end

  describe '#nsync_client' do
    it 'returns the diego nsync listener client' do
      expect(locator.nsync_client).to be_an_instance_of(VCAP::CloudController::Diego::NsyncClient)
    end
  end

  describe '#stager_client' do
    it 'returns the diego stager client' do
      expect(locator.stager_client).to be_an_instance_of(VCAP::CloudController::Diego::StagerClient)
    end
  end

  describe '#tps_client' do
    it 'returns the diego tps client' do
      expect(locator.tps_client).to be_an_instance_of(VCAP::CloudController::Diego::TPSClient)
    end
  end

  describe '#stagers' do
    it 'returns the stagers' do
      expect(locator.stagers).to be_an_instance_of(VCAP::CloudController::Stagers)
    end
  end

  describe '#runners' do
    it 'returns the runners' do
      expect(locator.runners).to be_an_instance_of(VCAP::CloudController::Runners)
    end
  end

  describe '#instances_reporters' do
    it 'returns the instances reporters' do
      expect(locator.instances_reporters).to be_an_instance_of(VCAP::CloudController::InstancesReporters)
    end
  end
end
