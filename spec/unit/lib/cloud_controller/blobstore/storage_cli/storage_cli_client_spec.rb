require 'spec_helper'
require 'cloud_controller/blobstore/storage_cli/azure_storage_cli_client'

module CloudController
  module Blobstore
    RSpec.describe StorageCliClient do
      describe 'registry build and lookup' do
        it 'builds the correct client when JSON has provider AzureRM' do
          droplets_cfg = Tempfile.new(['droplets', '.json'])
          droplets_cfg.write({ provider: 'AzureRM',
                               account_key: 'bommelkey',
                               account_name: 'bommel',
                               container_name: 'bommelcontainer',
                               environment: 'BommelCloud' }.to_json)
          droplets_cfg.flush

          config_double = instance_double(VCAP::CloudController::Config)
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          client_from_registry = StorageCliClient.build(
            directory_key: 'dummy-key',
            root_dir: 'dummy-root',
            resource_type: 'droplets'
          )
          expect(client_from_registry).to be_a(AzureStorageCliClient)

          droplets_cfg.close!
        end

        it 'raises an error for an unregistered provider' do
          droplets_cfg = Tempfile.new(['droplets', '.json'])
          droplets_cfg.write(
            { provider: 'UnknownProvider',
              account_key: 'bommelkey',
              account_name: 'bommel',
              container_name: 'bommelcontainer',
              environment: 'BommelCloud' }.to_json
          )
          droplets_cfg.flush

          config_double = instance_double(VCAP::CloudController::Config)
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          expect do
            StorageCliClient.build(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          end.to raise_error(RuntimeError, 'No storage CLI client registered for provider UnknownProvider')

          droplets_cfg.close!
        end

        it 'raises an error when provider is missing from the JSON' do
          droplets_cfg = Tempfile.new(['droplets', '.json'])
          droplets_cfg.write({}.to_json)
          droplets_cfg.flush

          config_double = instance_double(VCAP::CloudController::Config)
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          expect do
            StorageCliClient.build(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /No provider specified in config file/)

          droplets_cfg.close!
        end
      end

      describe 'resource_type → config file selection & validation' do
        let(:config_double) { instance_double(VCAP::CloudController::Config) }

        let(:droplets_cfg)      { Tempfile.new(['droplets', '.json']) }
        let(:buildpacks_cfg)    { Tempfile.new(['buildpacks', '.json']) }
        let(:packages_cfg)      { Tempfile.new(['packages', '.json']) }
        let(:resource_pool_cfg) { Tempfile.new(['resource_pool', '.json']) }

        before do
          [droplets_cfg, buildpacks_cfg, packages_cfg, resource_pool_cfg].each do |f|
            f.write({ provider: 'AzureRM',
                      account_key: 'bommelkey',
                      account_name: 'bommel',
                      container_name: 'bommelcontainer',
                      environment: 'BommelCloud' }.to_json)
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

          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil))
        end

        after do
          [droplets_cfg, buildpacks_cfg, packages_cfg, resource_pool_cfg].each(&:close!)
        end

        def build_client(resource_type)
          StorageCliClient.build(
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

        it 'raises when provider is missing from config file' do
          File.write(packages_cfg.path, {
            azure_storage_access_key: 'bommelkey',
            azure_storage_account_name: 'bommel',
            container_name: 'bommelcontainer',
            environment: 'BommelCloud'
          }.to_json)

          expect do
            build_client('packages')
          end.to raise_error(
            CloudController::Blobstore::BlobstoreError,
            /No provider specified/
          )
        end

        it 'raises BlobstoreError on invalid JSON' do
          File.write(droplets_cfg.path, '{not json')
          expect do
            StorageCliClient.build(directory_key: 'dir', root_dir: 'root', resource_type: 'droplets')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /Failed to parse storage-cli JSON/)
        end

        it 'raises when JSON is not an object' do
          File.write(droplets_cfg.path, '[]')
          expect do
            StorageCliClient.build(directory_key: 'dir', root_dir: 'root', resource_type: 'droplets')
          end.to raise_error(CloudController::Blobstore::BlobstoreError, /must be a JSON object/)
        end

        %w[account_key account_name container_name environment].each do |k|
          it "raises when #{k} missing" do
            cfg = { 'provider' => 'AzureRM', 'account_key' => 'a', 'account_name' => 'b',
                    'container_name' => 'c', 'environment' => 'd' }
            cfg.delete(k)
            File.write(droplets_cfg.path, cfg.to_json)
            expect do
              StorageCliClient.build(directory_key: 'dir', root_dir: 'root', resource_type: 'droplets')
            end.to raise_error(CloudController::Blobstore::BlobstoreError, /Missing required keys.*#{k}/)
          end
        end
      end

      describe '#exists? exit code handling' do
        let(:config_double) { instance_double(VCAP::CloudController::Config) }
        let(:droplets_cfg)  { Tempfile.new(['droplets', '.json']) }

        before do
          droplets_cfg.write({ provider: 'AzureRM',
                               account_key: 'bommelkey',
                               account_name: 'bommel',
                               container_name: 'bommelcontainer',
                               environment: 'BommelCloud' }.to_json)
          droplets_cfg.flush

          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
          allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)

          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil))
        end

        after { droplets_cfg.close! }

        let(:client) do
          StorageCliClient.build(
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
