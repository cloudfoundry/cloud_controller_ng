require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe ClientProvider do
      let(:options) { { blobstore_type: } }

      context 'when no type is requested' do
        let(:blobstore_type) { nil }

        before do
          options.merge!(fog_connection: {})
        end

        it 'provides a fog client' do
          allow(FogClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(FogClient).to have_received(:new)
        end
      end

      context 'when fog is requested' do
        let(:blobstore_type) { 'fog' }

        before do
          options.merge!(fog_connection: {})
        end

        it 'provides a fog client' do
          allow(FogClient).to receive(:new).and_call_original
          ClientProvider.provide(options: options, directory_key: 'key')
          expect(FogClient).to have_received(:new)
        end

        context 'when an aws encryption option is requested' do
          before do
            options.merge!(fog_aws_storage_options: { encryption: 'my organic algo' })
          end

          it 'passes the specified encryption option to the fog client' do
            allow(FogClient).to receive(:new).and_call_original
            ClientProvider.provide(options: options, directory_key: 'key')
            expect(FogClient).to have_received(:new).with(connection_config: anything,
                                                          directory_key: anything,
                                                          cdn: anything,
                                                          root_dir: anything,
                                                          min_size: anything,
                                                          max_size: anything,
                                                          aws_storage_options: { encryption: 'my organic algo' },
                                                          gcp_storage_options: anything)
          end

          context 'fog methods' do
            describe '#download_from_blobstore' do
              it 'receives all arguments' do
                allow_any_instance_of(FogClient).to receive(:download_from_blobstore).and_return(nil)

                client = ClientProvider.provide(options: options, directory_key: 'key')
                expect_any_instance_of(FogClient).to receive(:download_from_blobstore).with('key', 'dest', mode: 775)
                client.download_from_blobstore('key', 'dest', mode: 775)
              end
            end
          end
        end

        context 'when a gcp uniform option is requested' do
          before do
            options.merge!(fog_gcp_storage_options: { uniform: false })
          end

          it 'passes the specified uniform option to the fog client' do
            allow(FogClient).to receive(:new).and_call_original
            ClientProvider.provide(options: options, directory_key: 'key')
            expect(FogClient).to have_received(:new).with(connection_config: anything,
                                                          directory_key: anything,
                                                          cdn: anything,
                                                          root_dir: anything,
                                                          min_size: anything,
                                                          max_size: anything,
                                                          aws_storage_options: anything,
                                                          gcp_storage_options: { uniform: false })
          end
        end

        context 'when a cdn is requested in the options' do
          before do
            options.merge!(cdn: { uri: 'http://cdn.com' })
          end

          it 'sets up a cdn for the fog client' do
            allow(FogClient).to receive(:new).and_call_original
            ClientProvider.provide(options: options, directory_key: 'key')
            expect(FogClient).to have_received(:new).with(connection_config: anything,
                                                          directory_key: anything,
                                                          cdn: an_instance_of(Cdn),
                                                          root_dir: anything,
                                                          min_size: anything,
                                                          max_size: anything,
                                                          aws_storage_options: anything,
                                                          gcp_storage_options: anything)
          end
        end

        context 'when fog_connection is not provided' do
          before do
            options.delete(:fog_connection)
          end

          it 'raises an error' do
            expect { ClientProvider.provide(options: options, directory_key: 'key') }.to raise_error(KeyError)
          end
        end
      end

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
          File.write(config_path, '{"provider": "AzureRM",
                  "account_name": "some-account-name",
                  "account_key": "some-access-key",
                  "container_name": "directory_key",
                  "environment": "AzureCloud" }')
          allow(VCAP::CloudController::Config.config).to receive(:get).with(:storage_cli_config_file_droplets).and_return(config_path)
          options.merge!(provider: 'AzureRM', minimum_size: 100, maximum_size: 1000)
        end

        it 'provides a storage-cli client' do
          allow(StorageCliClient).to receive(:build).and_return(storage_cli_client_mock)
          ClientProvider.provide(options:, directory_key:, root_dir:, resource_type:)
          expect(StorageCliClient).to have_received(:build).with(directory_key: directory_key, resource_type: resource_type, root_dir: root_dir,
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
    end
  end
end
