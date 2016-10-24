require 'spec_helper'
require 'cloud_controller/dependency_locator'

RSpec.describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.instance }

  let(:config) { TestConfig.config }
  let(:bits_service_config) do
    {
      enabled: true,
      public_endpoint: 'https://bits-service.com',
      private_endpoint: 'http://bits-service.service.cf.internal'
    }
  end

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
        },
      }
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
        with(options: config[:droplets], directory_key: 'key', resource_type: :droplets)
      locator.droplet_blobstore
    end

    context('when bits service is enabled') do
      let(:config) do
        {
          droplets: {
            fog_connection: 'fog_connection',
            droplet_directory_key: 'key',
          },
          bits_service: bits_service_config
        }
      end

      it 'creates the client with the right arguments' do
        expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
          with(options: config[:droplets], directory_key: 'key', resource_type: :droplets)
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
        }
      }
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).with(
        options: config[:droplets],
        directory_key: 'key',
        root_dir: 'buildpack_cache',
        resource_type: :buildpack_cache)
      locator.buildpack_cache_blobstore
    end

    context('when bits service is enabled') do
      let(:config) do
        {
          droplets: {
            fog_connection: 'fog_connection',
            droplet_directory_key: 'key',
          },
          bits_service: bits_service_config
        }
      end

      it 'creates the client with the right arguments' do
        expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
          with(options: config[:droplets], directory_key: 'key', root_dir: 'buildpack_cache', resource_type: :buildpack_cache)
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
        }
      }
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
        with(options: config[:packages], directory_key: 'key', resource_type: :packages)
      locator.package_blobstore
    end

    context('when bits service is enabled') do
      let(:config) do
        {
          packages: {
            app_package_directory_key: 'key'
          },
          bits_service: bits_service_config
        }
      end

      it 'creates the client with the right arguments' do
        expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
          with(options: config[:packages], directory_key: 'key', resource_type: :packages)
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
        }
      }
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).with(options: config[:resource_pool], directory_key: 'key')
      locator.global_app_bits_cache
    end
  end

  describe '#blobstore_url_generator' do
    let(:internal_service_hostname) { 'internal.service.hostname' }
    let(:my_config) do
      {
        internal_service_hostname: internal_service_hostname,
        external_host:             'external.host',
        external_port:             8282,
        staging:                   {
          auth: {
            user:     'username',
            password: 'password',
          }
        }
      }
    end

    before do
      TestConfig.override(my_config)
    end

    it 'creates blobstore_url_generator with the internal_service_hostname, port, and blobstores' do
      connection_options = {
        blobstore_host: 'internal.service.hostname',
        blobstore_port: 8282,
        user:           'username',
        password:       'password'
      }
      expect(CloudController::Blobstore::UrlGenerator).to receive(:new).
        with(hash_including(connection_options),
          kind_of(CloudController::Blobstore::Client),
          kind_of(CloudController::Blobstore::Client),
          kind_of(CloudController::Blobstore::Client),
          kind_of(CloudController::Blobstore::Client)
        )
      locator.blobstore_url_generator
    end
  end

  describe '#app_event_repository' do
    subject { locator.app_event_repository }

    it { is_expected.to be_a(VCAP::CloudController::Repositories::AppEventRepository) }

    it 'memoizes the instance' do
      expect(locator.app_event_repository).to eq(locator.app_event_repository)
    end
  end

  describe '#space_event_repository' do
    subject { locator.space_event_repository }

    it { is_expected.to be_a(VCAP::CloudController::Repositories::SpaceEventRepository) }
  end

  describe '#user_event_repository' do
    subject { locator.user_event_repository }

    it { is_expected.to be_a(VCAP::CloudController::Repositories::UserEventRepository) }
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

  describe '#router_group_type_populating_collection_renderer' do
    it 'returns paginated collection renderer with a RouterGroupTypePopulator transformer' do
      renderer = locator.router_group_type_populating_collection_renderer
      expect(renderer.collection_transformer).to be_a(VCAP::CloudController::RouterGroupTypePopulator)
    end

    it 'uses the routing_api_client for the populator' do
      routing_api_client = double('routing api client')
      expect(locator).to receive(:routing_api_client).and_return(routing_api_client)
      renderer = locator.router_group_type_populating_collection_renderer
      expect(renderer.collection_transformer.routing_api_client).to eq(routing_api_client)
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

  describe '#routing_api_client' do
    let(:config) do
      TestConfig.override(routing_api:
                          {
        url: 'routing-api-url',
        routing_client_name: 'routing-client',
        routing_client_secret: 'routing-secret',
      }
                         )
      TestConfig.config
    end

    context 'when routing api in not enabled' do
      before do
        config[:routing_api] = nil
      end

      it 'returns a disabled client' do
        expect(locator.routing_api_client).
          to be_an_instance_of(VCAP::CloudController::RoutingApi::DisabledClient)
      end
    end

    it 'returns a routing_api_client' do
      name = config[:routing_api][:routing_client_name]
      secret = config[:routing_api][:routing_client_secret]
      uaa = config[:uaa][:url]
      opts = { skip_ssl_validation: config[:skip_cert_verify] }

      token_issuer = double('token_issuer')
      expect(CF::UAA::TokenIssuer).to receive(:new).with(uaa, name, secret, opts).and_return(token_issuer)

      client = locator.routing_api_client

      expect(client).to be_an_instance_of(VCAP::CloudController::RoutingApi::Client)
      expect(client.token_issuer).to eq token_issuer
      expect(client.routing_api_uri.to_s).to eq(config[:routing_api][:url])
      expect(client.skip_cert_verify).to eq(config[:skip_cert_verify])
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
