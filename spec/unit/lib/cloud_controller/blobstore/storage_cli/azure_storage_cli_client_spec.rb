require 'spec_helper'
require_relative '../client_shared'
require 'cloud_controller/blobstore/storage_cli/azure_storage_cli_client'
require 'cloud_controller/blobstore/storage_cli/storage_cli_blob'

module CloudController
  module Blobstore
    RSpec.describe AzureStorageCliClient do
      subject(:client) { AzureStorageCliClient.new(fog_connection: fog_connection, directory_key: directory_key, root_dir: 'bommel', fork: true) }
      let(:directory_key) { 'my-bucket' }
      let(:fog_connection) do
        {
          azure_storage_access_key: 'some-access-key',
          azure_storage_account_name: 'some-account-name',
          container_name: directory_key,
          environment: 'AzureCloud',
          provider: 'AzureRM'
        }
      end
      let(:downloaded_file) do
        Tempfile.open('') do |tmpfile|
          tmpfile.write('downloaded file content')
          tmpfile
        end
      end

      let(:deletable_blob) { StorageCliBlob.new('deletable-blob') }
      let(:dest_path) { File.join(Dir.mktmpdir, SecureRandom.uuid) }

      describe 'conforms to the blobstore client interface' do
        before do
          allow(client).to receive(:run_cli).with('exists', anything, allow_exit_code_three: true).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('get', anything, anything).and_wrap_original do |_original_method, _cmd, _source, dest_path|
            File.write(dest_path, 'downloaded content')
            [nil, instance_double(Process::Status, exitstatus: 0)]
          end
          allow(client).to receive(:run_cli).with('put', anything, anything).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('copy', anything, anything).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('delete', anything).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('delete-recursive', anything).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('list', anything).and_return(["aa/bb/blob1\ncc/dd/blob2\n", instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('ensure-bucket-exists', anything).and_return([nil, instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('properties', anything).and_return(['{"dummy": "json"}', instance_double(Process::Status, exitstatus: 0)])
          allow(client).to receive(:run_cli).with('sign', anything, 'get', '3600s').and_return(['some-url', instance_double(Process::Status, exitstatus: 0)])
        end

        it_behaves_like 'a blobstore client'
      end

      describe '#local?' do
        it 'returns false' do
          expect(client.local?).to be false
        end
      end

      describe 'config file' do
        it 'builds a valid config file' do
          expect(client.instance_variable_get(:@config_file)).to be_a(String)
          expect(File.exist?(client.instance_variable_get(:@config_file))).to be true
          expect(File.read(client.instance_variable_get(:@config_file))).to eq(
            '{"account_name":"some-account-name","account_key":"some-access-key","container_name":"my-bucket","environment":"AzureCloud"}'
          )
        end
      end

      describe '#cli_path' do
        it 'returns the default CLI path' do
          expect(client.cli_path).to eq('/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli')
        end

        it 'can be overridden by an environment variable' do
          allow(ENV).to receive(:[]).with('AZURE_STORAGE_CLI_PATH').and_return('/custom/path/to/azure-storage-cli')
          expect(client.cli_path).to eq('/custom/path/to/azure-storage-cli')
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
          allow(Open3).to receive(:capture3).with(anything, '-c', anything, 'list', 'arg1').and_return(['ok', '', status])

          output, returned_status = client.send(:run_cli, 'list', 'arg1')
          expect(output).to eq('ok')
          expect(returned_status).to eq(status)
        end

        it 'raises an error on failure' do
          status = instance_double(Process::Status, success?: false, exitstatus: 1)
          allow(Open3).to receive(:capture3).with(anything, '-c', anything, 'list', 'arg1').and_return(['', 'error message', status])

          expect do
            client.send(:run_cli, 'list', 'arg1')
          end.to raise_error(RuntimeError, /storage-cli list failed with exit code 1/)
        end

        it 'allows exit code 3 if specified' do
          status = instance_double(Process::Status, success?: false, exitstatus: 3)
          allow(Open3).to receive(:capture3).with(anything, '-c', anything, 'list', 'arg1').and_return(['', 'error message', status])

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
