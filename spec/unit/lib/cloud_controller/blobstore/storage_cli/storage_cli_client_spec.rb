require 'spec_helper'
require 'cloud_controller/blobstore/storage_cli/storage_cli_client'

module CloudController
  module Blobstore
    RSpec.describe StorageCliClient do
      # Helper methods
      def write_config_file(hash)
        file = Tempfile.new(['storage-cli', '.json'])
        file.write(hash.to_json)
        file.flush
        file
      end

      def stub_config_for_droplets(path)
        config_double = instance_double(VCAP::CloudController::Config)
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
        allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(path)
        allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil, debug: nil))
      end

      describe 'client init' do
        # DEPRECATED: Legacy fog provider tests - remove after migration window
        # START LEGACY FOG SUPPORT TESTS
        it 'maps AWS legacy provider to s3 storage-cli type' do
          droplets_cfg = write_config_file(
            provider: 'AWS',
            bucket_name: 'test-bucket',
            access_key_id: 'key',
            secret_access_key: 'secret'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('s3')
          ensure
            droplets_cfg.close!
          end
        end

        it 'maps Google legacy provider to gcs storage-cli type' do
          droplets_cfg = write_config_file(
            provider: 'Google',
            bucket_name: 'test-bucket',
            json_key: '{}'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('gcs')
          ensure
            droplets_cfg.close!
          end
        end

        it 'maps aliyun legacy provider to alioss storage-cli type' do
          droplets_cfg = write_config_file(
            provider: 'aliyun',
            access_key_id: 'key',
            access_key_secret: 'secret',
            endpoint: 'aliyun.com',
            bucket_name: 'bucket'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('alioss')
          ensure
            droplets_cfg.close!
          end
        end

        it 'maps webdav legacy provider to dav storage-cli type' do
          droplets_cfg = write_config_file(
            provider: 'webdav',
            endpoint: 'https://webdav.example.com',
            user: 'testuser',
            password: 'testpass'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('dav')
          ensure
            droplets_cfg.close!
          end
        end
        # END LEGACY FOG SUPPORT TESTS

        it 'raises an error for an unknown legacy provider' do
          droplets_cfg = write_config_file(
            provider: 'UnknownProvider',
            account_key: 'bommelkey',
            account_name: 'bommel',
            container_name: 'bommelcontainer',
            environment: 'BommelCloud'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            expect do
              StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
            end.to raise_error(RuntimeError, /Unknown provider: UnknownProvider/)
          ensure
            droplets_cfg.close!
          end
        end

        it 'init the correct client when JSON has provider azurebs (native storage-cli type)' do
          droplets_cfg = write_config_file(
            provider: 'azurebs',
            account_key: 'bommelkey',
            account_name: 'bommel',
            container_name: 'bommelcontainer',
            environment: 'BommelCloud'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('azurebs')
            expect(client.instance_variable_get(:@resource_type)).to eq('droplets')
            expect(client.instance_variable_get(:@root_dir)).to eq('dummy-root')
            expect(client.instance_variable_get(:@directory_key)).to eq('dummy-key')
          ensure
            droplets_cfg.close!
          end
        end

        it 'init the correct client when JSON has provider dav (native storage-cli type)' do
          droplets_cfg = write_config_file(
            provider: 'dav',
            endpoint: 'https://webdav.example.com',
            public_endpoint: 'https://cdn.example.com/admin/testbucket',
            user: 'testuser',
            password: 'testpassword',
            retryattempts: 5,
            secret: 'my-hmac-secret',
            tls: {
              cert: {
                ca: "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
              }
            }
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            client = StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
            expect(client.instance_variable_get(:@storage_type)).to eq('dav')
            expect(client.instance_variable_get(:@resource_type)).to eq('droplets')
            expect(client.instance_variable_get(:@root_dir)).to eq('dummy-root')
            expect(client.instance_variable_get(:@directory_key)).to eq('dummy-key')
          ensure
            droplets_cfg.close!
          end
        end

        it 'raises an error for an unknown storage-cli type' do
          droplets_cfg = write_config_file(
            provider: 'unknown_type',
            account_key: 'bommelkey',
            account_name: 'bommel',
            container_name: 'bommelcontainer',
            environment: 'BommelCloud'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            expect do
              StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
            end.to raise_error(RuntimeError, /Unknown provider: unknown_type/)
          ensure
            droplets_cfg.close!
          end
        end

        it 'raises an error when provider is missing' do
          droplets_cfg = write_config_file(
            account_key: 'bommelkey',
            account_name: 'bommel',
            container_name: 'bommelcontainer',
            environment: 'BommelCloud'
          )
          begin
            stub_config_for_droplets(droplets_cfg.path)

            expect do
              StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
            end.to raise_error(BlobstoreError, /No provider specified/)
          ensure
            droplets_cfg.close!
          end
        end

        it 'raises when resource_type is missing' do
          expect do
            StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: nil)
          end.to raise_error(RuntimeError, 'Missing resource_type')
        end
      end

      describe 'resource_type → config file selection & validation' do
        let(:config_double) { instance_double(VCAP::CloudController::Config) }

        let(:droplets_cfg)      { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }
        let(:buildpacks_cfg)    { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }
        let(:packages_cfg)      { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }
        let(:resource_pool_cfg) { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }

        before do
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)

          allow(config_double).to receive(:get) do |key|
            case key
            when :storage_cli_config_file_droplets      then droplets_cfg.path
            when :storage_cli_config_file_buildpacks    then buildpacks_cfg.path
            when :storage_cli_config_file_packages      then packages_cfg.path
            when :storage_cli_config_file_resource_pool then resource_pool_cfg.path
            end
          end

          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil, debug: nil))
        end

        after do
          [droplets_cfg, buildpacks_cfg, packages_cfg, resource_pool_cfg].each(&:close!)
        end

        def build_client(resource_type)
          StorageCliClient.new(
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
            account_key: 'bommelkey',
            account_name: 'bommel',
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
      end

      describe 'client helper operations' do
        describe 'Json operations' do
          let(:droplets_cfg) { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }

          before do
            stub_config_for_droplets(droplets_cfg.path)
          end

          after do
            droplets_cfg.close!
          end

          it 'raises BlobstoreError on invalid JSON' do
            File.write(droplets_cfg.path, '{not json')
            expect do
              StorageCliClient.new(directory_key: 'dir', root_dir: 'root', resource_type: 'droplets')
            end.to raise_error(CloudController::Blobstore::BlobstoreError, /Failed to parse storage-cli JSON/)
          end

          it 'raises when JSON is not an object' do
            File.write(droplets_cfg.path, '[]')
            expect do
              StorageCliClient.new(directory_key: 'dir', root_dir: 'root', resource_type: 'droplets')
            end.to raise_error(CloudController::Blobstore::BlobstoreError, /must be a JSON object/)
          end
        end

        describe 'with valid client' do
          let(:droplets_cfg) { write_config_file(provider: 'azurebs', account_key: 'key', account_name: 'acc', container_name: 'cont', environment: 'Cloud') }
          let(:client) do
            stub_config_for_droplets(droplets_cfg.path)

            StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
          end

          after do
            droplets_cfg.close!
          end

          it '#local? returns false' do
            expect(client.local?).to be false
          end

          it 'returns the default CLI path' do
            expect(client.send(:cli_path)).to eq('/var/vcap/packages/storage-cli/bin/storage-cli')
          end

          it 'can be overridden by an environment variable' do
            allow(ENV).to receive(:[]).and_call_original
            allow(ENV).to receive(:[]).with('STORAGE_CLI_PATH').and_return('/custom/path/to/storage-cli')
            expect(client.send(:cli_path)).to eq('/custom/path/to/storage-cli')
          end
        end
      end

      describe 'client operations' do
        let!(:tmp_cfg) do
          write_config_file(
            provider: 'azurebs',
            account_name: 'some-account-name',
            account_key: 'some-access-key',
            container_name: directory_key,
            environment: 'AzureCloud'
          )
        end

        before do
          cc_cfg = instance_double(VCAP::CloudController::Config)
          allow(VCAP::CloudController::Config).to receive(:config).and_return(cc_cfg)

          allow(cc_cfg).to receive(:get) do |key, *_|
            case key
            when :storage_cli_config_file_droplets,
              :storage_cli_config_file_buildpacks,
              :storage_cli_config_file_packages,
              :storage_cli_config_file_resource_pool
              tmp_cfg.path
            end
          end
          allow(Steno).to receive(:logger).and_return(double(info: nil, error: nil, debug: nil))
        end

        after { tmp_cfg.close! }

        subject(:client) { StorageCliClient.new(directory_key: directory_key, resource_type: resource_type, root_dir: 'bommel') }
        let(:directory_key) { 'my-bucket' }
        let(:resource_type) { 'resource_pool' }
        let(:deletable_blob) { StorageCliBlob.new('deletable-blob') }
        let(:dest_path) { File.join(Dir.mktmpdir, SecureRandom.uuid) }

        describe 'optional flags' do
          context 'when there is no extra flags' do
            before do
              allow(VCAP::CloudController::Config.config).to receive(:get).with(:storage_cli_optional_flags).and_return('')
            end

            it('returns empty list') {
              expect(client.send(:additional_flags)).to eq([])
            }
          end

          context 'when there is extra flags' do
            before do
              allow(VCAP::CloudController::Config.config).to receive(:get).with(:storage_cli_optional_flags).and_return('-log-level warn -log-file some/path/storage-cli.log')
            end

            it('returns list with parsed flags') {
              expect(client.send(:additional_flags)).to eq(['-log-level', 'warn', '-log-file', 'some/path/storage-cli.log'])
            }
          end
        end

        describe  '#exists?' do
          context 'when the blob exists' do
            before { allow(client).to receive(:run_cli).with('exists', any_args).and_return([nil, instance_double(Process::Status, exitstatus: 0)]) }

            it('returns true') { expect(client.exists?('some-blob-key')).to be true }
          end

          context 'when the blob does not exist' do
            before { allow(client).to receive(:run_cli).with('exists', any_args).and_return([nil, instance_double(Process::Status, exitstatus: 3)]) }

            it('returns false') { expect(client.exists?('some-blob-key')).to be false }
          end
        end

        describe '#files_for' do
          context 'when CLI returns multiple files' do
            let(:cli_output) { "aa/bb/blob1\ncc/dd/blob2\n" }

            before do
              allow(client).to receive(:run_cli).
                with('list', 'some-prefix').
                and_return([cli_output, instance_double(Process::Status, success?: true)])
            end

            it 'returns StorageCliBlob instances for each file' do
              blobs = client.files_for('some-prefix')
              expect(blobs.map(&:key)).to eq(['aa/bb/blob1', 'cc/dd/blob2'])
              expect(blobs).to all(be_a(StorageCliBlob))
            end
          end

          context 'when CLI returns empty output' do
            before do
              allow(client).to receive(:run_cli).
                with('list', 'some-prefix').
                and_return(["\n", instance_double(Process::Status, success?: true)])
            end

            it 'returns an empty array' do
              expect(client.files_for('some-prefix')).to eq([])
            end
          end

          context 'when CLI output has extra whitespace' do
            let(:cli_output) { "aa/bb/blob1 \n \ncc/dd/blob2\n" }

            before do
              allow(client).to receive(:run_cli).
                with('list', 'some-prefix').
                and_return([cli_output, instance_double(Process::Status, success?: true)])
            end

            it 'strips and rejects empty lines' do
              blobs = client.files_for('some-prefix')
              expect(blobs.map(&:key)).to eq(['aa/bb/blob1', 'cc/dd/blob2'])
            end
          end
        end

        describe '#blob' do
          let(:properties_json) { '{"etag": "test-etag", "last_modified": "2024-10-01T00:00:00Z", "content_length": 1024}' }

          context 'for non-DAV providers' do
            it 'returns a StorageCliBlob with a signed URL using the generic sign command (default use_internal_url: false)' do
              allow(client).to receive(:run_cli).with('properties', 'bommel/va/li/valid-blob').and_return([properties_json, instance_double(Process::Status, exitstatus: 0)])
              allow(client).to receive(:run_cli).with('sign', 'bommel/va/li/valid-blob', 'get', '3600s').and_return(['some-url', instance_double(Process::Status, exitstatus: 0)])

              blob = client.blob('valid-blob')
              expect(blob).to be_a(StorageCliBlob)
              expect(blob.key).to eq('valid-blob')
              expect(blob.attributes(:etag, :last_modified, :content_length)).to eq({
                                                                                      etag: 'test-etag',
                                                                                      last_modified: '2024-10-01T00:00:00Z',
                                                                                      content_length: 1024
                                                                                    })
              expect(blob.public_download_url).to eq('some-url')
            end

            it 'uses the generic sign command regardless of use_internal_url' do
              allow(client).to receive(:run_cli).with('properties', 'bommel/va/li/valid-blob').and_return([properties_json, instance_double(Process::Status, exitstatus: 0)])
              allow(client).to receive(:run_cli).with('sign', 'bommel/va/li/valid-blob', 'get', '3600s').and_return(['some-url', instance_double(Process::Status, exitstatus: 0)])

              blob = client.blob('valid-blob', use_internal_url: true)
              expect(blob.internal_download_url).to eq('some-url')
            end
          end

          context 'for DAV provider' do
            let!(:dav_cfg) do
              write_config_file(
                provider: 'dav',
                endpoint: 'https://blobstore.internal:4443/admin/cc-droplets',
                public_endpoint: 'https://blobstore.example.com/admin/cc-droplets',
                user: 'testuser',
                password: 'testpass',
              )
            end

            let(:dav_client) do
              stub_config_for_droplets(dav_cfg.path)
              StorageCliClient.new(
                directory_key: 'cc-droplets',
                root_dir: nil,
                resource_type: 'droplets'
              )
            end

            after { dav_cfg.close! }

            it 'invokes sign-internal when use_internal_url is true' do
              allow(dav_client).to receive(:run_cli).with('properties', 'dr/op/droplet-guid').and_return([properties_json, instance_double(Process::Status, exitstatus: 0)])
              allow(dav_client).to receive(:run_cli).with('sign-internal', 'dr/op/droplet-guid', 'get',
                                                          '3600s').and_return(['https://blobstore.internal:4443/read/cc-droplets/dr/op/droplet-guid?md5=abc&expires=123',
                                                                               instance_double(Process::Status, exitstatus: 0)])

              blob = dav_client.blob('droplet-guid', use_internal_url: true)
              expect(blob).to be_a(StorageCliBlob)
              expect(blob.internal_download_url).to eq('https://blobstore.internal:4443/read/cc-droplets/dr/op/droplet-guid?md5=abc&expires=123')
            end

            it 'invokes sign-public by default' do
              allow(dav_client).to receive(:run_cli).with('properties', 'dr/op/droplet-guid').and_return([properties_json, instance_double(Process::Status, exitstatus: 0)])
              allow(dav_client).to receive(:run_cli).with('sign-public', 'dr/op/droplet-guid', 'get',
                                                          '3600s').and_return(['https://blobstore.example.com/read/cc-droplets/dr/op/droplet-guid?md5=xyz&expires=456',
                                                                               instance_double(Process::Status, exitstatus: 0)])

              blob = dav_client.blob('droplet-guid')
              expect(blob.public_download_url).to eq('https://blobstore.example.com/read/cc-droplets/dr/op/droplet-guid?md5=xyz&expires=456')
            end
          end

          it 'raises an error if the cli output is empty' do
            allow(client).to receive(:run_cli).with('properties', 'bommel/no/ne/nonexistent-blob').and_return([nil, instance_double(Process::Status, exitstatus: 0)])
            expect { client.blob('nonexistent-blob') }.to raise_error(BlobstoreError, /Properties command returned empty output/)
          end

          it 'raises an error if the cli output is not valid JSON' do
            allow(client).to receive(:run_cli).with('properties', 'bommel/in/va/invalid-json').and_return(['not a json', instance_double(Process::Status, exitstatus: 0)])
            expect { client.blob('invalid-json') }.to raise_error(BlobstoreError, /Failed to parse json properties/)
          end
        end

        describe '#run_cli' do
          before do
            allow(client).to receive(:additional_flags).and_return([])
          end

          it 'returns output and status on success' do
            status = instance_double(Process::Status, success?: true, exitstatus: 0)
            allow(Open3).to receive(:capture3).and_return(['ok', '', status])

            output, returned_status = client.send(:run_cli, 'list', 'arg1')
            expect(output).to eq('ok')
            expect(returned_status).to eq(status)
          end

          it 'raises an error on failure' do
            status = instance_double(Process::Status, success?: false, exitstatus: 1)
            allow(Open3).to receive(:capture3).and_return(['', 'error message', status])

            expect do
              client.send(:run_cli, 'list', 'arg1')
            end.to raise_error(RuntimeError, /storage-cli list failed with exit code 1/)
          end

          it 'allows exit code 3 if specified' do
            status = instance_double(Process::Status, success?: false, exitstatus: 3)
            allow(Open3).to receive(:capture3).and_return(['', 'error message', status])

            output, returned_status = client.send(:run_cli, 'list', 'arg1', allow_exit_code_three: true)
            expect(output).to eq('')
            expect(returned_status).to eq(status)
          end

          it 'raises BlobstoreError on Open3 failure' do
            allow(Open3).to receive(:capture3).and_raise(StandardError.new('Open3 error'))

            expect { client.send(:run_cli, 'list', 'arg1') }.to raise_error(BlobstoreError, /Open3 error/)
          end
        end
      end
    end
  end
end
