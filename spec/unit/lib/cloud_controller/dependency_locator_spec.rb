require 'spec_helper'
require 'cloud_controller/dependency_locator'
require 'cloud_controller/diego/task_recipe_builder'

RSpec.describe CloudController::DependencyLocator do
  subject(:locator) { CloudController::DependencyLocator.instance }

  let(:config) { TestConfig.config_instance }

  before { locator.config = config }

  describe '#droplet_blobstore' do
    let(:config) do
      VCAP::CloudController::Config.new({
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
        },
      })
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
        with(options: config.get(:droplets), directory_key: 'key', resource_type: :droplets)
      locator.droplet_blobstore
    end
  end

  describe '#buildpack_cache_blobstore' do
    let(:config) do
      VCAP::CloudController::Config.new({
        droplets: {
          fog_connection: 'fog_connection',
          droplet_directory_key: 'key',
        }
      })
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).with(
        options: config.get(:droplets),
        directory_key: 'key',
        root_dir: 'buildpack_cache',
        resource_type: :buildpack_cache)
      locator.buildpack_cache_blobstore
    end
  end

  describe '#package_blobstore' do
    let(:config) do
      VCAP::CloudController::Config.new({
        packages: {
          fog_connection: 'fog_connection',
          app_package_directory_key: 'key',
        }
      })
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).
        with(options: config.get(:packages), directory_key: 'key', resource_type: :packages)
      locator.package_blobstore
    end
  end

  describe '#legacy_global_app_bits_cache' do
    let(:config) do
      VCAP::CloudController::Config.new({
        resource_pool: {
          fog_connection: 'fog_connection',
          resource_directory_key: 'key',
        }
      })
    end

    it 'creates blob store' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).with(
        options: config.get(:resource_pool),
        directory_key: 'key',
      )
      locator.legacy_global_app_bits_cache
    end
  end

  describe '#global_app_bits_cache' do
    let(:config) do
      VCAP::CloudController::Config.new({
        resource_pool: {
          fog_connection: 'fog_connection',
          resource_directory_key: 'key',
        }
      })
    end

    it 'creates blob store with a app_bits_cache as root_dir' do
      expect(CloudController::Blobstore::ClientProvider).to receive(:provide).with(
        options: config.get(:resource_pool),
        directory_key: 'key',
        root_dir: 'app_bits_cache',
      )
      locator.global_app_bits_cache
    end
  end

  describe '#blobstore_url_generator' do
    let(:internal_service_hostname) { 'internal.service.hostname' }
    let(:my_config) do
      {
        internal_service_hostname: internal_service_hostname,
        external_host:             'external.host',
        tls_port:                  8283,
        staging:                   {
          auth: {
            user:     'username',
            password: 'password',
          }
        },
      }
    end

    before do
      TestConfig.override(**my_config)
    end

    it 'creates blobstore_url_generator with the internal_service_hostname, port, and blobstores' do
      connection_options = {
        blobstore_host: 'internal.service.hostname',
        blobstore_external_port: 8181,
        blobstore_tls_port: 8283,
        user: 'username',
        password: 'password',
        mtls: true,
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

  describe '#droplet_url_generator' do
    let(:my_config) do
      {
        internal_service_hostname: 'internal.service.hostname',
        tls_port:                  8283,
      }
    end

    before do
      TestConfig.override(**my_config)
    end

    it 'creates droplet_url_generator with the internal_service_hostname, ports, and diego flag' do
      expect(VCAP::CloudController::Diego::Buildpack::DropletUrlGenerator).to receive(:new).with(
        internal_service_hostname: 'internal.service.hostname',
        external_port: nil,
        tls_port: 8283,
        mtls: true)
      TestConfig.config.delete(:external_port)
      locator.droplet_url_generator
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
      opts = { max_inline_relations_depth: 100_002, object_transformer: nil }

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

  describe '#username_populating_object_renderer' do
    it 'returns UsernamePopulator transformer' do
      renderer = locator.username_populating_object_renderer
      expect(renderer.object_transformer).to be_a(VCAP::CloudController::UsernamePopulator)
    end

    it 'uses the uaa_client for the populator' do
      uaa_client = double('uaa client')
      expect(locator).to receive(:uaa_client).and_return(uaa_client)
      renderer = locator.username_populating_object_renderer
      expect(renderer.object_transformer.uaa_client).to eq(uaa_client)
    end
  end

  describe '#username_populating_collection_renderer' do
    it 'returns paginated collection renderer with a UsernamePopulator transformer' do
      renderer = locator.username_populating_collection_renderer
      expect(renderer.collection_transformer).to be_a(VCAP::CloudController::UsernamePopulator)
    end

    it 'uses the uaa_client for the populator' do
      uaa_client = double('uaa client')
      expect(locator).to receive(:uaa_client).and_return(uaa_client)
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

  describe '#uaa_client' do
    context 'when a CA file is not configured for the UAA' do
      before do
        TestConfig.override(uaa: { ca_file: nil, internal_url: TestConfig.config_instance.get(:uaa, :internal_url) })
      end

      it 'returns a uaa client with credentials for looking up usernames' do
        uaa_client = locator.uaa_client
        expect(uaa_client.client_id).to eq(config.get(:cloud_controller_username_lookup_client_name))
        expect(uaa_client.secret).to eq(config.get(:cloud_controller_username_lookup_client_secret))
        expect(uaa_client.uaa_target).to eq(config.get(:uaa, :internal_url))
      end
    end

    context 'when a CA file is configured for the UAA' do
      it 'returns a uaa client with credentials for looking up usernames' do
        uaa_client = locator.uaa_client
        expect(uaa_client.client_id).to eq(config.get(:cloud_controller_username_lookup_client_name))
        expect(uaa_client.secret).to eq(config.get(:cloud_controller_username_lookup_client_secret))
        expect(uaa_client.uaa_target).to eq(config.get(:uaa, :internal_url))
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
      TestConfig.config_instance
    end

    context 'when routing api in not enabled' do
      before do
        config.set(:routing_api, nil)
      end

      it 'returns a disabled client' do
        expect(locator.routing_api_client).
          to be_an_instance_of(VCAP::CloudController::RoutingApi::DisabledClient)
      end
    end

    it 'returns a routing_api_client' do
      uaa_client = instance_double(VCAP::CloudController::UaaClient)
      expect(VCAP::CloudController::UaaClient).to receive(:new).with(
        uaa_target: config.get(:uaa, :internal_url),
        client_id: config.get(:routing_api, :routing_client_name),
        secret: config.get(:routing_api, :routing_client_secret),
        ca_file: config.get(:uaa, :ca_file),
      ).and_return(uaa_client)

      client = locator.routing_api_client

      expect(client).to be_an_instance_of(VCAP::CloudController::RoutingApi::Client)
      expect(client.uaa_client).to eq uaa_client
      expect(client.routing_api_uri.to_s).to eq(config.get(:routing_api, :url))
      expect(client.skip_cert_verify).to eq(config.get(:skip_cert_verify))
    end
  end

  describe '#credhub_client' do
    it 'returns a credhub_client' do
      token_info = instance_double(CF::UAA::TokenInfo, auth_header: 'bearer my-token')
      uaa_client = instance_double(VCAP::CloudController::UaaClient, token_info: token_info)
      expect(VCAP::CloudController::UaaClient).to receive(:new).with(
        uaa_target: config.get(:uaa, :internal_url),
        client_id: config.get(:cc_service_key_client_name),
        secret: config.get(:cc_service_key_client_secret),
        ca_file: config.get(:uaa, :ca_file),
      ).and_return(uaa_client)

      client = locator.credhub_client

      expect(client).to be_an_instance_of(Credhub::Client)
      expect(client.send(:credhub_url)).to eq(config.get(:credhub_api, :internal_url))
      expect(client.send(:auth_header)).to eq(token_info.auth_header)
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
      config.set(:nginx, config.get(:nginx).merge(use_nginx: true))
      expect(CloudController::BlobSender::NginxLocalBlobSender).to receive(:new).and_return(sender)
      expect(locator.blob_sender).to eq(sender)
    end

    it 'returns the correct sender when not using ngx' do
      config.set(:nginx, config.get(:nginx).merge(use_nginx: false))
      expect(CloudController::BlobSender::DefaultLocalBlobSender).to receive(:new).and_return(sender)
      expect(locator.blob_sender).to eq(sender)
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

  describe '#log_cache_metrics_client' do
    let(:logcache_client) { instance_double(Logcache::Client) }
    before do
      allow(Logcache::Client).to receive(:new).and_return(logcache_client)
    end

    it 'returns the tc-decorated client without TLS' do
      TestConfig.override(
        logcache_tls: nil
      )
      expect(locator.log_cache_metrics_client).to be_an_instance_of(Logcache::ContainerMetricBatcher)
      expect(Logcache::Client).to have_received(:new).with(
        host: 'http://doppler.service.cf.internal',
        port: 8080,
        client_ca_path: nil,
        client_cert_path: nil,
        client_key_path: nil,
        tls_subject_name: nil,
      )
    end

    it 'returns the tc-decorated client with TLS certificates' do
      TestConfig.override(
        logcache: {
          host: 'some-logcache-host',
          port: 1234,
        },
        logcache_tls: {
          ca_file: 'logcache-ca',
          cert_file: 'logcache-client-ca',
          key_file: 'logcache-client-key',
          subject_name: 'some-tls-cert-san'
        }
      )
      expect(locator.log_cache_metrics_client).to be_an_instance_of(Logcache::ContainerMetricBatcher)
      expect(Logcache::Client).to have_received(:new).with(
        host: 'some-logcache-host',
        port: 1234,
        client_ca_path: 'logcache-ca',
        client_cert_path: 'logcache-client-ca',
        client_key_path: 'logcache-client-key',
        tls_subject_name: 'some-tls-cert-san',
      )
    end
  end

  describe '#copilot_client' do
    let(:copilot_client) { instance_double(Cloudfoundry::Copilot::Client) }

    before do
      TestConfig.override(
        copilot: {
          enabled: true,
          host: 'some-host',
          port: 1234,
          client_ca_file: 'some-client-ca-file',
          client_key_file: 'some-client-key-file',
          client_chain_file: 'some-client-chain-file'
        }
      )
    end

    it 'returns the copilot client' do
      expect(Cloudfoundry::Copilot::Client).to receive(:new).with(
        host: 'some-host',
        port: 1234,
        client_ca_file: 'some-client-ca-file',
        client_key_file: 'some-client-key-file',
        client_chain_file: 'some-client-chain-file'
      ).and_return(copilot_client)
      expect(locator.copilot_client).to eq(copilot_client)
    end
  end

  describe '#statsd_client' do
    it 'returns the statsd client' do
      host = 'test-host'
      port = 1234

      TestConfig.override(
        statsd_host: host,
        statsd_port: port,
      )

      expected_client = double(Statsd)

      allow(Statsd).to receive(:new).with(host, port).
        and_return(expected_client)

      expect(locator.statsd_client).to eq(expected_client)
    end
  end

  describe '#bbs_stager_client' do
    let(:diego_client) { double }

    before do
      allow(::Diego::Client).to receive(:new).and_return(diego_client)
    end

    it 'uses diego' do
      expect(VCAP::CloudController::Diego::BbsStagerClient).to receive(:new).with(diego_client, config)
      locator.bbs_stager_client
    end
  end

  describe '#bbs_apps_client' do
    let(:diego_client) { double }

    before do
      allow(::Diego::Client).to receive(:new).and_return(diego_client)
    end

    it 'uses diego' do
      expect(VCAP::CloudController::Diego::BbsAppsClient).to receive(:new).with(diego_client, config)
      locator.bbs_apps_client
    end
  end

  describe '#build_instances_client' do
    let(:diego_client) { double }
    before do
      allow(::Diego::Client).to receive(:new).and_return(diego_client)
    end

    it 'uses diego' do
      expect(VCAP::CloudController::Diego::BbsInstancesClient).to receive(:new).with(diego_client)
      locator.bbs_instances_client
    end
  end

  describe '#bbs_task_client' do
    let(:diego_client) { double }

    before do
      allow(::Diego::Client).to receive(:new).and_return(diego_client)
    end

    it 'uses diego' do
      expect(VCAP::CloudController::Diego::BbsTaskClient).to receive(:new).with(config, diego_client)
      locator.bbs_task_client
    end
  end
end

def generate_test_kubeconfig
  ca_file = Tempfile.new('k8s_node_ca.crt')
  ca_file.write('my crt')
  ca_file.close

  token_file = Tempfile.new('token.token')
  token_file.write('token')
  token_file.close

  {
    kubernetes: {
      host_url: 'https://my.kubernetes.io',
      service_account: {
        token_file: token_file.path,
      },
      ca_file: ca_file.path
    },
  }
end
