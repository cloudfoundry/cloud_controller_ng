require 'spec_helper'
require 'webrick'
require_relative '../client_shared'

module CloudController
  module Blobstore
    # Minimal in-memory fog storage stub. Replaces Fog::Storage.new so that
    # FogClient specs can run without any fog provider gem being bundled.
    class FakeStorage
      FakeFile = Struct.new(:key, :body, :content_type, :public, :content_length, :bucket, keyword_init: true) do
        def public_url = public ? "http://fake/#{key}" : nil
        def copy(dest_bucket, dest_key, _opts = {})
          storage.store_file(dest_bucket, dest_key, body, content_type)
        end
        def destroy = storage.delete_file(bucket, key)

        attr_accessor :storage
      end

      def initialize
        @store = {}
      end

      def directories = DirectoryProxy.new(self)

      def respond_to?(method, *) = method == :directories || super

      def store_file(bucket, key, body, content_type)
        @store[bucket] ||= {}
        body_content = body.respond_to?(:read) ? body.read : body.to_s
        file = FakeFile.new(key: key, body: body_content, content_type: content_type, public: false,
                            content_length: body_content.bytesize, bucket: bucket)
        file.storage = self
        @store[bucket][key] = file
        file
      end

      def delete_file(bucket, key)
        @store[bucket]&.delete(key)
      end

      def list_files(bucket, prefix: nil)
        files = @store[bucket]&.values || []
        files = files.select { |f| f.key.start_with?(prefix) } if prefix
        files
      end

      def get_file(bucket, key)
        @store[bucket]&.[](key)
      end

      def bucket_exists?(key)
        @store.key?(key)
      end

      def create_bucket(key)
        @store[key] ||= {}
      end

      class DirectoryProxy
        def initialize(storage) = @storage = storage

        def get(key, **)
          return nil unless @storage.bucket_exists?(key)

          BucketProxy.new(@storage, key)
        end

        def create(key:, **) = BucketProxy.new(@storage, @storage.create_bucket(key) && key)
        def new(key:, **) = BucketProxy.new(@storage, key)
      end

      class BucketProxy
        attr_reader :key

        def initialize(storage, key)
          @storage = storage
          @key = key
          @storage.create_bucket(key)
        end

        def files = FilesProxy.new(@storage, @key)
      end

      class FilesProxy
        include Enumerable

        def initialize(storage, bucket)
          @storage = storage
          @bucket = bucket
        end

        def head(key) = @storage.get_file(@bucket, key)

        def get(key, &block)
          file = @storage.get_file(@bucket, key)
          return nil unless file

          if block
            yield file.body
          else
            file
          end
          file
        end

        def create(key:, body:, content_type: 'application/zip', **)
          @storage.store_file(@bucket, key, body, content_type)
        end

        def each(&block) = all.each(&block)
        def all = @storage.list_files(@bucket)

        def select(prefix: nil)
          @storage.list_files(@bucket, prefix:)
        end
      end
    end

    RSpec.describe FogClient do
      let(:content) { 'Some Nonsense' }
      let(:sha_of_content) { Digester.new.digest(content) }
      let(:local_dir) { Dir.mktmpdir }
      let(:fake_storage) { FakeStorage.new }
      let(:connection_config) { { provider: 'fake' } }
      let(:directory_key) { 'a-directory-key' }

      subject(:client) do
        FogClient.new(connection_config:, directory_key:)
      end

      before do
        allow(Fog::Storage).to receive(:new).and_return(fake_storage)
      end

      after do
        FileUtils.rm_rf(local_dir)
      end

      it 'logs a deprecation warning on initialization' do
        expect_any_instance_of(Steno::Logger).to receive(:warn).with('blobstore.fog-deprecated', hash_including(:message))
        FogClient.new(connection_config:, directory_key:)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(FogBlob, file: nil) }

        before do
          client.ensure_bucket_exists
          client.cp_to_blobstore(tmpfile.path, key)
        end

        it_behaves_like 'a blobstore client'
      end

      def upload_tmpfile(client, key='abcdef')
        Tempfile.open('') do |tmpfile|
          tmpfile.write(content)
          tmpfile.close
          client.cp_to_blobstore(tmpfile.path, key)
        end
      end

      context 'for a remote blobstore backed by a CDN' do
        let(:cdn) { double(:cdn) }
        let(:url_from_cdn) { 'http://some_distribution.cloudfront.net/ab/cd/abcdef' }
        let(:key) { 'abcdef' }

        subject(:client) do
          FogClient.new(connection_config:, directory_key:, cdn:)
        end

        before do
          client.ensure_bucket_exists
          upload_tmpfile(client, key)
          allow(cdn).to receive(:download_uri).and_return(url_from_cdn)
        end

        it 'downloads through the CDN' do
          expect(cdn).to receive(:get).
            with('ab/cd/abcdef').
            and_yield('foobar').and_yield(' barbaz')

          destination = File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file')

          expect { client.download_from_blobstore(key, destination) }.to change {
            File.exist?(destination)
          }.from(false).to(true)

          expect(File.read(destination)).to eq('foobar barbaz')
        end
      end

      context 'common behaviors' do
        let(:directory) { fake_storage.directories.get(directory_key) || fake_storage.directories.create(key: directory_key) }
        let(:client) do
          FogClient.new(connection_config:, directory_key:)
        end

        before do
          client.ensure_bucket_exists
        end

        context 'with existing files' do
          before do
            upload_tmpfile(client, sha_of_content)
          end

          describe 'a file existence' do
            it 'does not exist if not present' do
              different_content        = 'foobar'
              sha_of_different_content = Digester.new.digest(different_content)

              expect(client.exists?(sha_of_different_content)).to be false

              upload_tmpfile(client, sha_of_different_content)

              expect(client.exists?(sha_of_different_content)).to be true
              expect(client.blob(sha_of_different_content)).to be
            end
          end
        end

        describe '#cp_r_to_blobstore' do
          let(:sha_of_nothing) { Digester.new.digest('') }

          it 'ensures that the sha of nothing and sha of content are different for subsequent tests' do
            expect(sha_of_nothing[0..1]).not_to eq(sha_of_content[0..1])
          end

          it 'copies the top-level local files into the blobstore' do
            FileUtils.touch(File.join(local_dir, 'empty_file'))
            client.cp_r_to_blobstore(local_dir)
            expect(client.exists?(sha_of_nothing)).to be true
          end

          it 'recursively copies the local files into the blobstore' do
            subdir = File.join(local_dir, 'subdir1', 'subdir2')
            FileUtils.mkdir_p(subdir)
            File.write(File.join(subdir, 'file_with_content'), content)

            client.cp_r_to_blobstore(local_dir)
            expect(client.exists?(sha_of_content)).to be true
          end

          context 'when the file already exists in the blobstore' do
            before do
              FileUtils.touch(File.join(local_dir, 'empty_file'))
            end

            it 'does not re-upload it' do
              client.cp_r_to_blobstore(local_dir)

              expect(client).not_to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(local_dir)
            end
          end

          context 'limit the file size' do
            let(:min_size) { 20 }
            let(:max_size) { 50 }

            subject(:client) do
              FogClient.new(connection_config:, directory_key:, min_size:, max_size:)
            end

            it 'does not copy files below the minimum size limit' do
              path = File.join(local_dir, 'file_with_little_content')
              File.write(path, 'a')

              expect(client).not_to receive(:exists?)
              expect(client).not_to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end

            it 'does not copy files above the maximum size limit' do
              path = File.join(local_dir, 'file_with_more_content')
              File.write(path, 'an amount of content that is larger than the maximum limit')

              expect(client).not_to receive(:exists?)
              expect(client).not_to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end
          end

          context 'limit the file mode to those with sufficient permissions' do
            subject(:client) do
              FogClient.new(connection_config:, directory_key:)
            end

            it 'copies files with mode >= 0600' do
              path = File.join(local_dir, 'file_with_sufficient_permissions')
              FileUtils.touch(path)
              File.chmod(0o600, path)

              expect(client).to receive(:exists?)
              expect(client).to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end

            it 'does not copy files below the minimum file mode' do
              path = File.join(local_dir, 'file_with_insufficient_permissions')
              FileUtils.touch(path)
              File.chmod(0o444, path)

              expect(client).not_to receive(:exists?)
              expect(client).not_to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end
          end
        end

        describe '#download_from_blobstore' do
          let(:destination) { File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file') }

          context 'when directly from the underlying storage' do
            before do
              upload_tmpfile(client, sha_of_content)
            end

            it 'can download the file' do
              expect(client.exists?(sha_of_content)).to be true

              expect { client.download_from_blobstore(sha_of_content, destination) }.to change {
                File.exist?(destination)
              }.from(false).to(true)

              expect(File.read(destination)).to eq(content)
            end
          end

          describe 'file permissions' do
            before do
              upload_tmpfile(client, sha_of_content)
              @original_umask = File.umask
              File.umask(0o022)
            end

            after do
              File.umask(@original_umask)
            end

            context 'when not specifying a mode' do
              it 'does not change permissions on the file' do
                destination = File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file')
                client.download_from_blobstore(sha_of_content, destination)

                expect(sprintf('%<mode>o', mode: File.stat(destination).mode)).to eq('100644')
              end
            end

            context 'when specifying a mode' do
              it 'does change permissions on the file' do
                destination = File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file')
                client.download_from_blobstore(sha_of_content, destination, mode: 0o753)

                expect(sprintf('%<mode>o', mode: File.stat(destination).mode)).to eq('100753')
              end
            end
          end
        end

        describe '#cp_to_blobstore' do
          it 'uploads the files with the specified key' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to be true
            expect(directory.files.all.length).to eq(1)
          end

          it 'defaults to private files' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)
            key = 'abcdef12345'

            client.cp_to_blobstore(path, key)
            expect(client.blob(key).file.public_url).to be_nil
          end

          it 'sets content-type to mime-type of application/zip when not specified' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')

            expect(directory.files.head('ab/cd/abcdef123456').content_type).to eq('application/zip')
          end

          it 'sets content-type to mime-type of file when specified' do
            path = File.join(local_dir, 'empty_file.png')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')

            expect(directory.files.head('ab/cd/abcdef123456').content_type).to eq('image/png')
          end

          context 'limit the file size' do
            let(:min_size) { 20 }
            let(:max_size) { 50 }

            subject(:client) do
              FogClient.new(connection_config:, directory_key:, min_size:, max_size:)
            end

            it 'does not copy files below the minimum size limit' do
              path = File.join(local_dir, 'file_with_little_content')
              File.write(path, 'a')
              key = '987654321'

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be false
            end

            it 'does not copy files above the maximum size limit' do
              path = File.join(local_dir, 'file_with_more_content')
              File.write(path, 'an amount of content that is larger than the maximum limit')
              key = '777777777'

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be false
            end
          end
        end

        describe '#cp_file_between_keys' do
          let(:src_key) { 'abc123' }
          let(:dest_key) { 'xyz789' }

          it 'copies the file from the source key to the destination key' do
            upload_tmpfile(client, src_key)
            client.cp_file_between_keys(src_key, dest_key)

            expect(client.exists?(dest_key)).to be true
            expect(directory.files.all.length).to eq(2)
          end

          context 'when the destination key has a package already' do
            before do
              upload_tmpfile(client, src_key)
              Tempfile.open('') do |tmpfile|
                tmpfile.write('This should be deleted and replaced with new file')
                tmpfile.close
                client.cp_to_blobstore(tmpfile.path, dest_key)
              end
            end

            it 'replaces the old package in the package blobstore' do
              client.cp_file_between_keys(src_key, dest_key)
              expect(directory.files.all.length).to eq(2)

              src_file_length  = client.blob(dest_key).file.content_length
              dest_file_length = client.blob(src_key).file.content_length
              expect(dest_file_length).to eq(src_file_length)
            end
          end

          context 'when the source key has no file associated with it' do
            it 'does not attempt to copy over to the destination key' do
              expect do
                client.cp_file_between_keys('bogus', dest_key)
              end.to raise_error(CloudController::Blobstore::FileNotFound)

              expect(directory.files.all.length).to eq(0)
            end
          end
        end

        describe '#delete_all' do
          before do
            client.ensure_bucket_exists
          end

          it 'deletes all the files' do
            first_path = File.join(local_dir, 'first_empty_file')
            FileUtils.touch(first_path)
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(first_path, 'ab56')
            expect(client.exists?('ab56')).to be true
            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to be true

            client.delete_all

            expect(client.exists?('ab56')).to be false
            expect(client.exists?('abcdef123456')).to be false
          end

          it 'is ok if there are no files' do
            expect(directory.files.all.length).to eq(0)
            expect { client.delete_all }.not_to raise_error
          end

          context 'when a root dir is provided' do
            let(:root_dir) { 'root-dir' }

            let(:client_with_root) do
              FogClient.new(connection_config:, directory_key:, root_dir:)
            end

            before do
              client_with_root.ensure_bucket_exists
            end

            it 'only deletes files at the root' do
              allow(client_with_root).to receive(:delete_files).and_call_original

              file = File.join(local_dir, 'empty_file')
              FileUtils.touch(file)

              client.cp_to_blobstore(file, 'abcdef1')
              client_with_root.cp_to_blobstore(file, 'abcdef2')

              client_with_root.delete_all

              expect(client_with_root).to have_received(:delete_files) do |files|
                expect(files.length).to eq(1)
              end
            end
          end
        end

        describe '#delete_all_in_path' do
          before do
            client.ensure_bucket_exists
          end

          it 'deletes all the files within a specific path' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            remote_path_1 = 'aaaaguid'
            remote_key_1  = "#{remote_path_1}/stack_1"
            remote_key_2  = "#{remote_path_1}/stack_2"
            remote_path_2 = 'bbbbguid'
            remote_key_3  = "#{remote_path_2}/stack_3"

            client.cp_to_blobstore(path, remote_key_1)
            client.cp_to_blobstore(path, remote_key_2)
            client.cp_to_blobstore(path, remote_key_3)
            expect(client.exists?(remote_key_1)).to be true
            expect(client.exists?(remote_key_2)).to be true
            expect(client.exists?(remote_key_3)).to be true

            client.delete_all_in_path(remote_path_1)

            expect(client.exists?(remote_key_1)).to be false
            expect(client.exists?(remote_key_2)).to be false
            expect(client.exists?(remote_key_3)).to be true
          end

          it 'is ok if there are no files' do
            expect(directory.files.all.length).to eq(0)
            expect { client.delete_all_in_path('nonsense_path') }.not_to raise_error
          end

          context 'when a root dir is provided' do
            let(:root_dir) { 'root-dir' }

            let(:client_with_root) do
              FogClient.new(connection_config:, directory_key:, root_dir:)
            end

            before do
              client_with_root.ensure_bucket_exists
            end

            it 'only deletes files at the root' do
              path = File.join(local_dir, 'empty_file')
              FileUtils.touch(path)

              remote_path_1 = 'aaaaguid'
              remote_key_1  = "#{remote_path_1}/stack_1"
              remote_key_2  = "#{remote_path_1}/stack_2"
              remote_path_2 = 'bbbbguid'
              remote_key_3  = "#{remote_path_2}/stack_3"

              client_with_root.cp_to_blobstore(path, remote_key_1)
              client_with_root.cp_to_blobstore(path, remote_key_2)
              client_with_root.cp_to_blobstore(path, remote_key_3)
              expect(client_with_root.exists?(remote_key_1)).to be true
              expect(client_with_root.exists?(remote_key_2)).to be true
              expect(client_with_root.exists?(remote_key_3)).to be true

              client_with_root.delete_all_in_path(remote_path_1)

              expect(client_with_root.exists?(remote_key_1)).to be false
              expect(client_with_root.exists?(remote_key_2)).to be false
              expect(client_with_root.exists?(remote_key_3)).to be true
            end
          end
        end

        describe '#delete' do
          it 'deletes the file' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to be true
            client.delete('abcdef123456')
            expect(client.exists?('abcdef123456')).to be false
          end

          it "is ok if the file doesn't exist" do
            expect(directory.files.all.length).to eq(0)
            expect { client.delete('non-existent-file') }.not_to raise_error
          end
        end

        describe '#delete_blob' do
          it "deletes the blob's file" do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to be(true)

            blob = client.blob('abcdef123456')

            client.delete_blob(blob)
            expect(client.exists?('abcdef123456')).to be(false)
          end

          it "is ok if the file doesn't exist" do
            blob = FogBlob.new(nil, nil)
            expect { client.delete_blob(blob) }.not_to raise_error
          end
        end

        describe '#ensure_bucket_exists' do
          it 'gets the bucket' do
            expect(fake_storage.directories).to receive(:get).with(directory_key, max_keys: 1).and_call_original
            subject.ensure_bucket_exists
          end

          context 'the bucket exists' do
            it 'does not create the bucket' do
              subject.ensure_bucket_exists
              expect(fake_storage.directories).not_to receive(:create).with(key: directory_key, public: false)
              subject.ensure_bucket_exists
            end
          end

          context 'the bucket does not exist' do
            it 'creates the bucket' do
              allow(fake_storage.directories).to receive(:get).with(directory_key, max_keys: 1).and_return(nil)
              expect(fake_storage.directories).to receive(:create).with(key: directory_key, public: false).and_call_original
              subject.ensure_bucket_exists
            end
          end
        end
      end

      context 'with root directory specified' do
        let(:root_dir) { 'my-root' }

        let(:client_with_root) do
          FogClient.new(connection_config:, directory_key:, root_dir:)
        end

        before do
          client_with_root.ensure_bucket_exists
        end

        it 'includes the directory in the partitioned key' do
          upload_tmpfile(client_with_root, 'abcdef')
          expect(client_with_root.exists?('abcdef')).to be true
          expect(client_with_root.blob('abcdef')).to be
          expect(client_with_root.blob('abcdef').public_download_url).to match(%r{my-root/ab/cd/abcdef})
        end
      end

      describe 'downloading without mocking' do
        def wait_for_server_to_accept_requests(uri)
          code       = nil
          total_time = 0
          while code != '200' && total_time < 10
            begin
              res        = Net::HTTP.get_response(URI(uri))
              code       = res.code
              total_time += 0.1
              sleep 0.1
            rescue StandardError
            end
          end
        end

        describe 'from a CDN' do
          let(:port) { 9875 }
          let(:uri) { "http://localhost:#{port}" }
          let(:cdn) { Cdn.make(uri) }

          subject(:client) do
            FogClient.new(connection_config:, directory_key:, cdn:)
          end

          around do |example|
            WebMock.disable_net_connect!(allow_localhost: true)
            example.run
            WebMock.disable_net_connect!
          end

          it 'correctly downloads byte streams' do
            source_directory_path = File.expand_path('../../../../../fixtures/', File.dirname(__FILE__))
            source_file_path      = File.join(source_directory_path, 'pa/rt/partitioned_key')
            source_hexdigest      = OpenSSL::Digest::SHA256.file(source_file_path).hexdigest

            pid = spawn("ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => #{port}, :DocumentRoot => \"#{source_directory_path}\").start'", out: 'test.out', err: 'test.err')

            begin
              Process.detach(pid)

              wait_for_server_to_accept_requests(uri)

              destination_file_path = File.join(local_dir, 'hard_file.xyz')

              client.download_from_blobstore('partitioned_key', destination_file_path)

              destination_hexdigest = OpenSSL::Digest::SHA256.file(destination_file_path).hexdigest

              expect(destination_hexdigest).to eq(source_hexdigest)
            ensure
              Process.kill(9, pid)
            end
          end
        end

        describe 'from a blobstore' do
          it 'correctly downloads byte streams' do
            content = 'some binary content for checksum verification'
            source_file = Tempfile.new('source')
            source_file.write(content)
            source_file.close

            source_hexdigest = OpenSSL::Digest::SHA256.file(source_file.path).hexdigest

            client.ensure_bucket_exists
            client.cp_to_blobstore(source_file.path, 'partitioned_key')

            destination_file_path = File.join(local_dir, 'hard_file.xyz')
            client.download_from_blobstore('partitioned_key', destination_file_path)

            destination_hexdigest = OpenSSL::Digest::SHA256.file(destination_file_path).hexdigest

            expect(destination_hexdigest).to eq(source_hexdigest)
          ensure
            source_file&.unlink
          end
        end
      end
    end
  end
end
