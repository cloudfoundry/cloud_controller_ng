require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe BaseClient do
      subject(:client) do
        test_client = Class.new(BaseClient) do
          def exists?(_key)
            @exists
          end

          def cp_to_blobstore(path, sha1)
            # Track calls for testing
          end
        end.new

        test_client.instance_variable_set(:@min_size, 0)
        test_client.instance_variable_set(:@max_size, nil)
        test_client.instance_variable_set(:@root_dir, nil)
        test_client.instance_variable_set(:@exists, false)
        test_client
      end

      let(:source_dir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(source_dir)
      end

      describe '#cp_r_to_blobstore' do
        before do
          allow(client).to receive(:cp_to_blobstore)
        end

        context 'with files in batches of 50' do
          it 'processes all files including those beyond the first 50' do
            # Create 52 files to exceed batch size
            files = []
            52.times do |i|
              file = File.join(source_dir, "file_#{i}")
              File.write(file, "content#{i}")
              File.chmod(0o600, file)
              files << file
            end

            client.cp_r_to_blobstore(source_dir)

            # All 52 files should be processed
            expect(client).to have_received(:cp_to_blobstore).exactly(52).times
          end
        end

        context 'filtering' do
          before do
            # Create various types of items in the directory
            @valid_file = File.join(source_dir, 'valid_file')
            File.write(@valid_file, 'x' * 50) # make file large enough for size limit tests
            File.chmod(0o600, @valid_file)

            @directory = File.join(source_dir, 'subdir')
            Dir.mkdir(@directory)
          end

          it 'skips directories' do
            client.cp_r_to_blobstore(source_dir)

            expect(client).to have_received(:cp_to_blobstore).once
          end

          context 'with file permissions' do
            it 'skips files with insufficient permissions' do
              low_perm_file = File.join(source_dir, 'low_perm_file')
              File.write(low_perm_file, 'x' * 50)
              File.chmod(0o444, low_perm_file) # read-only

              client.cp_r_to_blobstore(source_dir)

              # Only the valid_file (with 0o600) should be processed
              expect(client).to have_received(:cp_to_blobstore).once
            end

            it 'includes files with sufficient permissions (0o600 or higher)' do
              high_perm_file = File.join(source_dir, 'high_perm_file')
              File.write(high_perm_file, 'x' * 50)
              File.chmod(0o755, high_perm_file)

              client.cp_r_to_blobstore(source_dir)

              # Both files should be processed
              expect(client).to have_received(:cp_to_blobstore).twice
            end
          end

          context 'with size limits' do
            before do
              client.instance_variable_set(:@min_size, 10)
              client.instance_variable_set(:@max_size, 100)
            end

            it 'skips files below minimum size' do
              small_file = File.join(source_dir, 'small_file')
              File.write(small_file, 'a')
              File.chmod(0o600, small_file)

              client.cp_r_to_blobstore(source_dir)

              # Only valid_file should be copied, not small_file
              expect(client).to have_received(:cp_to_blobstore).once
            end

            it 'skips files above maximum size' do
              large_file = File.join(source_dir, 'large_file')
              File.write(large_file, 'x' * 200)
              File.chmod(0o600, large_file)

              client.cp_r_to_blobstore(source_dir)

              # Only valid_file should be copied, not large_file
              expect(client).to have_received(:cp_to_blobstore).once
            end
          end
        end

        context 'when a file already exists in the blobstore' do
          it 'does not copy it again' do
            file1 = File.join(source_dir, 'file1')
            file2 = File.join(source_dir, 'file2')
            File.write(file1, 'x' * 50)
            File.write(file2, 'y' * 50)
            File.chmod(0o600, file1)
            File.chmod(0o600, file2)

            sha1_file1 = Digester.new.digest_path(file1)

            allow(client).to receive(:exists?) do |sha1|
              sha1 == sha1_file1
            end

            client.cp_r_to_blobstore(source_dir)

            # Only file2 should be copied, not file1
            expect(client).to have_received(:cp_to_blobstore).once
          end
        end

        it 'computes sha1 and passes it to cp_to_blobstore' do
          file = File.join(source_dir, 'test_file')
          File.write(file, 'test content')
          File.chmod(0o600, file)

          expected_sha1 = Digester.new.digest_path(file)

          client.cp_r_to_blobstore(source_dir)

          expect(client).to have_received(:cp_to_blobstore).with(file, expected_sha1)
        end
      end
    end
  end
end
