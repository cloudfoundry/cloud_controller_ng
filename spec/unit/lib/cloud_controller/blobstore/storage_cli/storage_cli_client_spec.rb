require 'spec_helper'
require 'cloud_controller/blobstore/storage_cli/storage_cli_client'

module CloudController
  module Blobstore
    RSpec.describe StorageCliClient do
      describe 'client init' do
        it 'init the correct client when JSON has provider AzureRM' do
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

          client = StorageCliClient.new(
            directory_key: 'dummy-key',
            root_dir: 'dummy-root',
            resource_type: 'droplets'
          )
          expect(client.instance_variable_get(:@provider)).to eq('AzureRM')
          expect(client.instance_variable_get(:@storage_type)).to eq('azurebs')
          expect(client.instance_variable_get(:@resource_type)).to eq('droplets')
          expect(client.instance_variable_get(:@root_dir)).to eq('dummy-root')
          expect(client.instance_variable_get(:@directory_key)).to eq('dummy-key')

          droplets_cfg.close!
        end

        it 'raises an error for an unimplemented provider' do
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
            StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: 'droplets')
          end.to raise_error(RuntimeError, 'Unimplemented provider: UnknownProvider, implemented ones are: AzureRM, aliyun, Google, AWS')

          droplets_cfg.close!
        end

        it 'raise when no resource type' do
          expect do
            StorageCliClient.new(directory_key: 'dummy-key', root_dir: 'dummy-root', resource_type: nil)
          end.to raise_error(RuntimeError, 'Missing resource_type')
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
            AzureRM_storage_access_key: 'bommelkey',
            AzureRM_storage_account_name: 'bommel',
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
          let(:droplets_cfg) do
            f = Tempfile.new(['droplets', '.json'])
            f.write({ provider: 'AzureRM',
                      account_key: 'bommelkey',
                      account_name: 'bommel',
                      container_name: 'bommelcontainer',
                      environment: 'BommelCloud' }.to_json)
            f.flush
            f
          end

          let(:config_double) { instance_double(VCAP::CloudController::Config) }

          before do
            allow(VCAP::CloudController::Config).to receive(:config).and_return(config_double)
            allow(config_double).to receive(:get).with(:storage_cli_config_file_droplets).and_return(droplets_cfg.path)
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
          let(:client) do
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

            StorageCliClient.new(
              directory_key: 'dummy-key',
              root_dir: 'dummy-root',
              resource_type: 'droplets'
            )
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
          f = Tempfile.new(['storage_cli_config', '.json'])
          f.write({ provider: 'AzureRM',
                    account_name: 'some-account-name',
                    account_key: 'some-access-key',
                    container_name: directory_key,
                    environment: 'AzureCloud' }.to_json)
          f.flush
          f
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
        let(:downloaded_file) do
          Tempfile.open('') do |tmpfile|
            tmpfile.write('downloaded file content')
            tmpfile
          end
        end

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

            it('returns empty list') {
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

          it 'returns a list of StorageCliBlob instances for a given key' do
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
            expect(blob.internal_download_url).to eq('some-url')
            expect(blob.public_download_url).to eq('some-url')
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
          it 'returns output and status on success' do
            status = instance_double(Process::Status, success?: true, exitstatus: 0)
            allow(Open3).to receive(:capture3).with(anything, '-s', anything, '-c', anything, 'list', 'arg1').and_return(['ok', '', status])

            output, returned_status = client.send(:run_cli, 'list', 'arg1')
            expect(output).to eq('ok')
            expect(returned_status).to eq(status)
          end

          it 'raises an error on failure' do
            status = instance_double(Process::Status, success?: false, exitstatus: 1)
            allow(Open3).to receive(:capture3).with(anything, '-s', anything, '-c', anything, 'list', 'arg1').and_return(['', 'error message', status])

            expect do
              client.send(:run_cli, 'list', 'arg1')
            end.to raise_error(RuntimeError, /storage-cli list failed with exit code 1/)
          end

          it 'allows exit code 3 if specified' do
            status = instance_double(Process::Status, success?: false, exitstatus: 3)
            allow(Open3).to receive(:capture3).with(anything, '-s', anything, '-c', anything, 'list', 'arg1').and_return(['', 'error message', status])

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
