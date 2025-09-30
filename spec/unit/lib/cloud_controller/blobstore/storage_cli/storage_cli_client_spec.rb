require 'spec_helper'
require 'cloud_controller/blobstore/storage_cli/azure_storage_cli_client'

module CloudController
  module Blobstore
    RSpec.describe StorageCliClient do
      describe 'registry build and lookup' do
        it 'builds the correct client' do
          droplets_cfg = Tempfile.new(['droplets', '.json'])
          droplets_cfg.write({ connection_config: { provider: 'AzureRM' } }.to_json)
          droplets_cfg.flush

          config_double = instance_double(VCAP::CloudController::Config)
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          client_from_registry = StorageCliClient.build(connection_config: { provider: 'AzureRM' }, directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          expect(client_from_registry).to be_a(AzureStorageCliClient)

          droplets_cfg.close!
        end

        it 'raises an error for an unregistered provider' do
          expect do
            StorageCliClient.build(connection_config: { provider: 'UnknownProvider' }, directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          end.to raise_error(RuntimeError, 'No storage CLI client registered for provider UnknownProvider')
        end

        it 'raises an error if provider is missing' do
          expect do
            StorageCliClient.build(connection_config: {}, directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          end.to raise_error(RuntimeError, 'Missing connection_config[:provider]')
        end
      end

      describe 'resource_type → config file selection & validation' do
        let(:config_double) { instance_double(VCAP::CloudController::Config) }

        let(:droplets_cfg)      { Tempfile.new(['droplets', '.json']) }
        let(:buildpacks_cfg)    { Tempfile.new(['buildpacks', '.json']) }
        let(:packages_cfg)      { Tempfile.new(['packages', '.json']) }
        let(:resource_pool_cfg) { Tempfile.new(['resource_pool', '.json']) }

        before do
          # Valid JSON (YAML can parse JSON)
          [droplets_cfg, buildpacks_cfg, packages_cfg, resource_pool_cfg].each do |f|
            f.write({ connection_config: { provider: 'AzureRM' } }.to_json)
            f.flush
          end

          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)

          allow(config_double).to receive(:get) do |key|
            case key
            when :storage_cli_config_file_droplets      then droplets_cfg.path
            when :storage_cli_config_file_buildpacks    then buildpacks_cfg.path
            when :storage_cli_config_file_packages      then packages_cfg.path
            when :storage_cli_config_file_resource_pool then resource_pool_cfg.path
            end
          end

          # Quiet logger noise in specs
          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil))
        end

        after do
          [droplets_cfg, buildpacks_cfg, packages_cfg, resource_pool_cfg].each(&:close!)
        end

        def build_client(resource_type)
          StorageCliClient.build(
            connection_config: { provider: 'AzureRM' },
            directory_key: 'dir-key',
            root_dir: 'root',
            resource_type: resource_type
          )
        end

        it 'picks droplets file for "droplets"' do
          client = build_client('droplets')
          expect(client.instance_variable_get(:@config_file)).to eq(droplets_cfg.path)
        end

        it 'picks droplets file for "buildpack_cache" too' do
          client = build_client('buildpack_cache')
          expect(client.instance_variable_get(:@config_file)).to eq(droplets_cfg.path)
        end

        it 'picks buildpacks file for "buildpacks"' do
          client = build_client('buildpacks')
          expect(client.instance_variable_get(:@config_file)).to eq(buildpacks_cfg.path)
        end

        it 'picks packages file for "packages"' do
          client = build_client('packages')
          expect(client.instance_variable_get(:@config_file)).to eq(packages_cfg.path)
        end

        it 'picks resource_pool file for "resource_pool"' do
          client = build_client('resource_pool')
          expect(client.instance_variable_get(:@config_file)).to eq(resource_pool_cfg.path)
        end

        it 'accepts a symbol and normalizes it' do
          client = build_client(:droplets)
          expect(client.instance_variable_get(:@config_file)).to eq(droplets_cfg.path)
        end

        it 'raises for unknown resource_type' do
          expect do
            build_client('nope')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /Unknown resource_type: nope/)
        end

        it 'raises when file missing/unreadable' do
          allow(config_double).to receive(:get).with(:storage_cli_config_file_packages).and_return('/no/such/file.json')
          expect do
            build_client('packages')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /not found or not readable/)
        end

        it 'raises when YAML load fails' do
          File.write(packages_cfg.path, '{ this is: [not, valid }')
          expect do
            build_client('packages')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /Failed to load storage-cli config/)
        end
      end

      describe '#exists? exit code handling' do
        let(:config_double) { instance_double(VCAP::CloudController::Config) }
        let(:droplets_cfg)  { Tempfile.new(['droplets', '.json']) }

        before do
          droplets_cfg.write({ connection_config: { provider: 'AzureRM' } }.to_json)
          droplets_cfg.flush

          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          # Avoid logger noise
          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil))
        end

        after { droplets_cfg.close! }

        let(:client) do
          StorageCliClient.build(
            connection_config: { provider: 'AzureRM' },
            directory_key: 'dir',
            root_dir: 'root',
            resource_type: 'droplets'
          )
        end

        it 'returns true on exitstatus 0' do
          expect(Open3).to receive(:capture3).
            with(kind_of(String), '-c', droplets_cfg.path, 'exists', kind_of(String)).
            and_return(['', '', instance_double(Process::Status, success?: true, exitstatus: 0)])

          expect(client.exists?('key')).to be true
        end

        it 'returns false on exitstatus 3' do
          expect(Open3).to receive(:capture3).
            with(kind_of(String), '-c', droplets_cfg.path, 'exists', kind_of(String)).
            and_return(['', '', instance_double(Process::Status, success?: false, exitstatus: 3)])

          expect(client.exists?('key')).to be false
        end

        it 'raises for other non-zero exit codes' do
          expect(Open3).to receive(:capture3).
            with(kind_of(String), '-c', droplets_cfg.path, 'exists', kind_of(String)).
            and_return(['', 'boom', instance_double(Process::Status, success?: false, exitstatus: 2)])

          expect { client.exists?('key') }.to raise_error(/storage-cli exists failed/)
        end
      end
    end
  end
end
