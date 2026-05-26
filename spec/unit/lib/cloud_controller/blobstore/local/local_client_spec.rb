require 'spec_helper'
require_relative '../client_shared'

module CloudController
  module Blobstore
    RSpec.describe LocalClient do
      subject(:client) do
        LocalClient.new(
          directory_key: directory_key,
          base_path: base_path,
          root_dir: root_dir,
          min_size: min_size,
          max_size: max_size
        )
      end

      let(:directory_key) { 'test-directory' }
      let(:base_path) { Dir.mktmpdir }
      let(:root_dir) { nil }
      let(:min_size) { nil }
      let(:max_size) { nil }
      let(:logger) { instance_double(Steno::Logger, error: nil, info: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      after do
        FileUtils.rm_rf(base_path)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(LocalBlob, key: 'te/st/test-key') }

        before do
          # The shared examples expect certain files to exist
          # Create the file that the tests will try to download/copy
          key = 'blobstore-client-shared-key'
          file_path = File.join(base_path, directory_key, 'bl', 'ob', key)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, 'shared test content')
        end

        it_behaves_like 'a blobstore client'
      end

      describe '#local?' do
        it 'returns true' do
          expect(client.local?).to be(true)
        end
      end

      describe '#exists?' do
        it 'returns false if the file does not exist' do
          expect(client.exists?('non-existent-key')).to be(false)
        end

        it 'returns true if the file exists' do
          key = 'abcdef123456'
          path = File.join(base_path, directory_key, 'ab', 'cd', key)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'test content')

          expect(client.exists?(key)).to be(true)
        end
      end

      describe '#cp_to_blobstore' do
        it 'copies a file to the blobstore with partitioned path' do
          source_file = Tempfile.new('source')
          source_file.write('test content')
          source_file.close

          key = 'abcdef123456'
          client.cp_to_blobstore(source_file.path, key)

          expected_path = File.join(base_path, directory_key, 'ab', 'cd', key)
          expect(File.exist?(expected_path)).to be(true)
          expect(File.read(expected_path)).to eq('test content')

          source_file.unlink
        end

        it 'does not copy if file size is below min_size' do
          client = LocalClient.new(directory_key: directory_key, base_path: base_path, min_size: 100)

          source_file = Tempfile.new('source')
          source_file.write('small')
          source_file.close

          key = 'test-key'
          client.cp_to_blobstore(source_file.path, key)

          expected_path = File.join(base_path, directory_key, 'te', 'st', key)
          expect(File.exist?(expected_path)).to be(false)

          source_file.unlink
        end

        it 'raises FileNotFound if source file does not exist' do
          expect do
            client.cp_to_blobstore('/non/existent/source/file', 'some-key')
          end.to raise_error(FileNotFound, /Could not find source file/)
        end
      end

      describe '#download_from_blobstore' do
        it 'downloads a file from the blobstore' do
          key = 'abcdef123456'
          source_path = File.join(base_path, directory_key, 'ab', 'cd', key)
          FileUtils.mkdir_p(File.dirname(source_path))
          File.write(source_path, 'stored content')

          dest_file = Tempfile.new('dest')
          dest_file.close
          dest_path = dest_file.path

          client.download_from_blobstore(key, dest_path)

          expect(File.read(dest_path)).to eq('stored content')

          dest_file.unlink
        end

        it 'raises FileNotFound if the file does not exist' do
          dest_path = File.join(Dir.mktmpdir, 'dest')
          expect do
            client.download_from_blobstore('non-existent', dest_path)
          end.to raise_error(FileNotFound)
        end

        it 'sets file mode if provided' do
          key = 'test-key'
          source_path = File.join(base_path, directory_key, 'te', 'st', key)
          FileUtils.mkdir_p(File.dirname(source_path))
          File.write(source_path, 'content')

          dest_file = Tempfile.new('dest')
          dest_file.close
          dest_path = dest_file.path

          client.download_from_blobstore(key, dest_path, mode: 0o600)

          expect(File.stat(dest_path).mode.to_s(8)[-3..]).to eq('600')

          dest_file.unlink
        end
      end

      describe '#cp_file_between_keys' do
        it 'copies a file from one key to another' do
          source_key = 'source123456'
          dest_key = 'dest123456'

          source_path = File.join(base_path, directory_key, 'so', 'ur', source_key)
          FileUtils.mkdir_p(File.dirname(source_path))
          File.write(source_path, 'content to copy')

          client.cp_file_between_keys(source_key, dest_key)

          dest_path = File.join(base_path, directory_key, 'de', 'st', dest_key)
          expect(File.exist?(dest_path)).to be(true)
          expect(File.read(dest_path)).to eq('content to copy')
        end

        it 'raises FileNotFound if source does not exist' do
          expect do
            client.cp_file_between_keys('non-existent', 'dest')
          end.to raise_error(FileNotFound)
        end
      end

      describe '#delete' do
        it 'deletes a file' do
          key = 'test123456'
          file_path = File.join(base_path, directory_key, 'te', 'st', key)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, 'content')

          expect(File.exist?(file_path)).to be(true)
          client.delete(key)
          expect(File.exist?(file_path)).to be(false)
        end

        it 'does not raise error if file does not exist' do
          expect { client.delete('non-existent') }.not_to raise_error
        end

        it 'cleans up empty parent directories after deletion' do
          key = 'test123456'
          file_path = File.join(base_path, directory_key, 'te', 'st', key)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, 'content')

          client.delete(key)

          # The partitioned directories (te/st/) should be removed since they're empty
          expect(Dir.exist?(File.join(base_path, directory_key, 'te', 'st'))).to be(false)
          expect(Dir.exist?(File.join(base_path, directory_key, 'te'))).to be(false)
          # But the base directory should still exist
          expect(Dir.exist?(File.join(base_path, directory_key))).to be(true)
        end

        it 'does not remove non-empty parent directories' do
          key1 = 'test123456'
          key2 = 'test789012'
          file_path1 = File.join(base_path, directory_key, 'te', 'st', key1)
          file_path2 = File.join(base_path, directory_key, 'te', 'st', key2)
          FileUtils.mkdir_p(File.dirname(file_path1))
          File.write(file_path1, 'content1')
          File.write(file_path2, 'content2')

          client.delete(key1)

          # The directory should still exist because key2 is still there
          expect(Dir.exist?(File.join(base_path, directory_key, 'te', 'st'))).to be(true)
          expect(File.exist?(file_path2)).to be(true)
        end
      end

      describe '#blob' do
        it 'returns a LocalBlob for an existing file' do
          key = 'test123456'
          file_path = File.join(base_path, directory_key, 'te', 'st', key)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, 'content')

          blob = client.blob(key)
          expect(blob).to be_a(LocalBlob)
          expect(blob.key).to eq('te/st/test123456')
        end

        it 'returns nil for non-existent file' do
          expect(client.blob('non-existent')).to be_nil
        end
      end

      describe '#delete_all' do
        it 'deletes all files in the directory' do
          %w[test1 test2 test3].each do |key|
            path = File.join(base_path, directory_key, 'te', 'st', key)
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, 'content')
          end

          client.delete_all

          expect(Dir.exist?(File.join(base_path, directory_key))).to be(true)
          expect(Dir.glob(File.join(base_path, directory_key, '**', '*')).select { |f| File.file?(f) }).to be_empty
        end
      end

      describe '#delete_all_in_path' do
        it 'deletes all files in a specific path' do
          path1 = File.join(base_path, directory_key, 'path1', 'file1')
          path2 = File.join(base_path, directory_key, 'path2', 'file2')

          FileUtils.mkdir_p(File.dirname(path1))
          FileUtils.mkdir_p(File.dirname(path2))
          File.write(path1, 'content1')
          File.write(path2, 'content2')

          client.delete_all_in_path('path1')

          expect(File.exist?(path1)).to be(false)
          expect(File.exist?(path2)).to be(true)
        end
      end

      describe '#files_for' do
        it 'returns an enumerator of blobs matching the prefix' do
          %w[aa/bb/test1 aa/cc/test2 ab/cd/test3].each do |path|
            full_path = File.join(base_path, directory_key, path)
            FileUtils.mkdir_p(File.dirname(full_path))
            File.write(full_path, 'content')
          end

          blobs = client.files_for('aa').to_a
          expect(blobs.length).to eq(2)
          expect(blobs).to all(be_a(LocalBlob))
        end
      end

      describe '#ensure_bucket_exists' do
        it 'creates the base path directory' do
          new_base = File.join(Dir.mktmpdir, 'new-base')
          client = LocalClient.new(directory_key: 'test', base_path: new_base)

          FileUtils.rm_rf(new_base)
          expect(Dir.exist?(File.join(new_base, 'test'))).to be(false)

          client.ensure_bucket_exists

          expect(Dir.exist?(File.join(new_base, 'test'))).to be(true)

          FileUtils.rm_rf(new_base)
        end
      end

      describe 'temp storage mode' do
        let(:temp_storage_client) do
          LocalClient.new(directory_key: 'temp-test', base_path: nil, use_temp_storage: true)
        end

        after do
          # Manually clean up since we can't rely on at_exit in tests
          path = temp_storage_client.instance_variable_get(:@base_path)
          FileUtils.rm_rf(path) if path && File.directory?(path)
        end

        it 'creates a temporary directory' do
          path = temp_storage_client.instance_variable_get(:@base_path)
          expect(path).to include('cc-blobstore-')
          expect(path).to include('temp-test')
          expect(File.directory?(path)).to be(true)
        end

        it 'stores files in the temporary directory' do
          source_file = Tempfile.new('temp-source')
          source_file.write('temp content')
          source_file.close

          key = 'test123456'
          temp_storage_client.cp_to_blobstore(source_file.path, key)

          expect(temp_storage_client.exists?(key)).to be(true)

          source_file.unlink
        end

        it 'cleans up the temporary directory' do
          path = temp_storage_client.instance_variable_get(:@base_path)
          expect(File.directory?(path)).to be(true)

          temp_storage_client.send(:cleanup_temp_storage)

          expect(File.directory?(path)).to be(false)
        end

        it 'logs error if cleanup fails' do
          path = temp_storage_client.instance_variable_get(:@base_path)

          # Need a real logger instance for this test since at_exit runs outside test lifecycle
          real_logger = instance_double(Steno::Logger, info: nil, error: nil)
          temp_storage_client.instance_variable_set(:@logger, real_logger)

          allow(FileUtils).to receive(:rm_rf).with(path).and_raise(StandardError.new('permission denied'))

          expect(real_logger).to receive(:error).with('temp-storage-cleanup-failed', error: 'permission denied', path: path)

          temp_storage_client.send(:cleanup_temp_storage)

          # Clean up manually since rm_rf was mocked
          allow(FileUtils).to receive(:rm_rf).and_call_original
        end
      end

      describe 'persistent mode (default)' do
        it 'requires base_path for persistent storage' do
          expect do
            LocalClient.new(directory_key: 'persistent-test', base_path: nil)
          end.to raise_error(ArgumentError, /local_blobstore_path is required/)
        end

        it 'keeps existing files' do
          existing_path = File.join(base_path, 'persistent-test', 'old-file')
          FileUtils.mkdir_p(File.dirname(existing_path))
          File.write(existing_path, 'old content')

          expect(File.exist?(existing_path)).to be(true)

          LocalClient.new(directory_key: 'persistent-test', base_path: base_path)

          expect(File.exist?(existing_path)).to be(true)
        end

        it 'is the default when use_temp_storage is not specified' do
          existing_path = File.join(base_path, 'default-test', 'old-file')
          FileUtils.mkdir_p(File.dirname(existing_path))
          File.write(existing_path, 'old content')

          expect(File.exist?(existing_path)).to be(true)

          LocalClient.new(
            directory_key: 'default-test',
            base_path: base_path
          )

          expect(File.exist?(existing_path)).to be(true)
        end
      end
    end
  end
end
