require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe ClientProvider do
      let(:options) { { blobstore_type: } }

      context 'when webdav is requested' do
        let(:blobstore_type) { 'webdav' }

        before do
          options.merge!(webdav_config: { private_endpoint: 'http://private.example.com', public_endpoint: 'http://public.example.com' })
        end

        it 'provides a webdav client' do
          allow(DavClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(DavClient).to have_received(:new)
        end
      end

      context 'when storage-cli is requested' do
        let(:blobstore_type) { 'storage-cli' }
        let(:directory_key) { 'some-bucket' }
        let(:resource_type) { 'droplets' }
        let(:root_dir) { 'some-root-dir' }
        let(:storage_cli_client_mock) { class_double(CloudController::Blobstore::StorageCliClient) }
        let(:tmpdir)         { Dir.mktmpdir('storage_cli_spec') }
        let(:config_path)    { File.join(tmpdir, 'storage_cli_config_droplets.json') }

        before do
          File.write(config_path, '{"provider": "azurebs",
                  "account_name": "some-account-name",
                  "account_key": "some-access-key",
                  "container_name": "directory_key",
                  "environment": "AzureCloud" }')
          allow(VCAP::CloudController::Config.config).to receive(:get).with(:storage_cli_config_file_droplets).and_return(config_path)
          options.merge!(provider: 'azurebs', minimum_size: 100, maximum_size: 1000)
        end

        it 'provides a storage-cli client' do
          allow(StorageCliClient).to receive(:new).and_return(storage_cli_client_mock)
          ClientProvider.provide(options:, directory_key:, root_dir:, resource_type:)
          expect(StorageCliClient).to have_received(:new).with(directory_key: directory_key, resource_type: resource_type, root_dir: root_dir,
                                                               min_size: 100, max_size: 1000)
        end

        it 'raises an error if provider is not provided' do
          config_path = VCAP::CloudController::Config.config.get(:storage_cli_config_file_droplets)
          File.write(config_path,
                     '{"provider": "", "account_name": "some-account-name", "account_key": "some-access-key", "container_name": "directory_key", "environment": "AzureCloud" }')
          expect { ClientProvider.provide(options:, directory_key:, root_dir:, resource_type:) }.to raise_error(BlobstoreError) { |e|
            expect(e.message).to include('No provider specified in config file:')
            expect(e.message).to include(File.basename(config_path))
          }
        end
      end

      context 'when local is requested' do
        let(:blobstore_type) { 'local' }
        let(:base_path) { Dir.mktmpdir }

        after do
          FileUtils.rm_rf(base_path)
        end

        before do
          options.merge!(local_blobstore_path: base_path, minimum_size: 100, maximum_size: 1000)
        end

        it 'provides a local client' do
          allow(LocalClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(LocalClient).to have_received(:new).with(
            directory_key: 'key',
            base_path: base_path,
            root_dir: nil,
            min_size: 100,
            max_size: 1000,
            use_temp_storage: false
          )
        end
      end

      context 'when local-temp-storage is requested' do
        let(:blobstore_type) { 'local-temp-storage' }

        before do
          options.merge!(minimum_size: 100, maximum_size: 1000)
        end

        it 'provides a local client with temp storage enabled' do
          allow(LocalClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(LocalClient).to have_received(:new).with(
            directory_key: 'key',
            base_path: nil,
            root_dir: nil,
            min_size: 100,
            max_size: 1000,
            use_temp_storage: true
          )
        end
      end
    end
  end
end
