require 'spec_helper'
require 'webrick'
require_relative '../client_shared'
require 'fog/aws/models/storage/files'

module CloudController
  module Blobstore
    RSpec.describe FogClient do
      let(:content) { 'Some Nonsense' }
      let(:sha_of_content) { Digester.new.digest(content) }
      let(:local_dir) { Dir.mktmpdir }
      let(:connection_config) do
        {
          provider:              'AWS',
          aws_access_key_id:     'fake_access_key_id',
          aws_secret_access_key: 'fake_secret_access_key',
        }
      end
      let(:directory_key) { 'a-directory-key' }
      let(:client_with_root) do
        described_class.new(connection_config: connection_config,
                            directory_key: directory_key,
                            root_dir: root_dir)
      end

      subject(:client) do
        described_class.new(connection_config: connection_config,
                            directory_key: directory_key)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(FogBlob, file: nil) }

        before do
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

      after do
        Fog::Mock.reset
      end

      context 'for a remote blobstore backed by a CDN' do
        let(:cdn) { double(:cdn) }
        let(:url_from_cdn) { 'http://some_distribution.cloudfront.net/ab/cd/abcdef' }
        let(:key) { 'abcdef' }

        subject(:client) do
          described_class.new(connection_config: connection_config,
                              directory_key: directory_key,
                              cdn: cdn)
        end

        before do
          upload_tmpfile(client, key)
          allow(cdn).to receive(:download_uri).and_return(url_from_cdn)
        end

        it 'is not local' do
          expect(client).to_not be_local
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

      context 'a local blobstore' do
        let(:connection_config) { { provider: 'Local' } }

        it 'is true if the provider is local' do
          expect(client).to be_local
        end
      end

      context 'common behaviors' do
        let(:directory) { Fog::Storage.new(connection_config).directories.create(key: directory_key) }
        let(:client) { described_class.new(connection_config: connection_config,
                                           directory_key: directory_key)
        }

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
            File.open(File.join(subdir, 'file_with_content'), 'w') { |file| file.write(content) }

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
              described_class.new(connection_config: connection_config,
                                  directory_key: directory_key,
                                  min_size: min_size,
                                  max_size: max_size)
            end

            it 'does not copy files below the minimum size limit' do
              path = File.join(local_dir, 'file_with_little_content')
              File.open(path, 'w') { |file| file.write('a') }

              expect(client).not_to receive(:exists)
              expect(client).not_to receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end

            it 'does not copy files above the maximum size limit' do
              path = File.join(local_dir, 'file_with_more_content')
              File.open(path, 'w') { |file| file.write('an amount of content that is larger than the maximum limit') }

              expect(client).not_to receive(:exists)
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
              File.umask(0022)
            end

            after do
              File.umask(@original_umask)
            end

            context 'when not specifying a mode' do
              it 'does not change permissions on the file' do
                destination = File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file')
                client.download_from_blobstore(sha_of_content, destination)

                expect(sprintf('%o', File.stat(destination).mode)).to eq('100644')
              end
            end

            context 'when specifying a mode' do
              it 'does change permissions on the file' do
                destination = File.join(local_dir, 'some_directory_to_place_file', 'downloaded_file')
                client.download_from_blobstore(sha_of_content, destination, mode: 0753)

                expect(sprintf('%o', File.stat(destination).mode)).to eq('100753')
              end
            end
          end
        end

        describe '#cp_to_blobstore' do
          it 'calls the fog with public false' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'foobar')

            expect(directory.files.head('fo/ob/foobar').public?).to be_falsey
          end

          it 'uploads the files with the specified key' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to be true
            expect(directory.files).to have(1).item
          end

          it 'defaults to private files' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)
            key = 'abcdef12345'

            client.cp_to_blobstore(path, key)
            expect(client.blob(key).file.public_url).to be_nil
          end

          it 'can copy as a public file' do
            allow(client).to receive(:local?) { true }
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)
            key = 'abcdef12345'

            client.cp_to_blobstore(path, key)
            expect(client.blob(key).file.public_url).to be
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
              described_class.new(connection_config: connection_config,
                                  directory_key: directory_key,
                                  min_size: min_size,
                                  max_size: max_size)
            end

            it 'does not copy files below the minimum size limit' do
              path = File.join(local_dir, 'file_with_little_content')
              File.open(path, 'w') { |file| file.write('a') }
              key = '987654321'

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be false
            end

            it 'does not copy files above the maximum size limit' do
              path = File.join(local_dir, 'file_with_more_content')
              File.open(path, 'w') { |file| file.write('an amount of content that is larger than the maximum limit') }
              key = '777777777'

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be false
            end
          end

          context 'encryption' do
            let(:files) { double(:files, create: true) }

            before do
              allow_any_instance_of(FogClient).to receive(:files).and_return(files)
            end

            context 'when encryption type is specified' do
              let(:client_with_encryption) { described_class.new(connection_config: connection_config,
                                                                 directory_key: directory_key,
                                                                 encryption: 'my-algo')
              }

              it 'passes the encryption options to aws' do
                path = File.join(local_dir, 'empty_file.png')
                FileUtils.touch(path)

                client_with_encryption.cp_to_blobstore(path, 'abcdef123456')

                expect(files).to have_received(:create).with(key: anything,
                                                             body: anything,
                                                             content_type: anything,
                                                             public: anything,
                                                             encryption: 'my-algo')
              end
            end

            context 'when encryption type is not specified' do
              let(:client_with_encryption) { described_class.new(connection_config: connection_config,
                                                                 directory_key: directory_key)
              }

              it 'passes the encryption options to aws' do
                path = File.join(local_dir, 'empty_file.png')
                FileUtils.touch(path)

                client_with_encryption.cp_to_blobstore(path, 'abcdef123456')

                expect(files).to have_received(:create).with(key: anything,
                                                             body: anything,
                                                             content_type: anything,
                                                             public: anything)
              end
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
            expect(directory.files).to have(2).item
          end

          context 'when the source file is public' do
            it 'copies as a public file' do
              allow(client).to receive(:local?) { true }
              upload_tmpfile(client, src_key)

              client.cp_file_between_keys(src_key, dest_key)
              expect(client.blob(dest_key).file.public_url).to be
            end
          end

          context 'when the source file is private' do
            it 'does not have a public url' do
              upload_tmpfile(client, src_key)
              client.cp_file_between_keys(src_key, dest_key)
              expect(client.blob(dest_key).file.public_url).to be_nil
            end
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

            it 'removes the old package from the package blobstore' do
              client.cp_file_between_keys(src_key, dest_key)
              expect(directory.files).to have(2).item

              src_file_length  = client.blob(dest_key).file.content_length
              dest_file_length = client.blob(src_key).file.content_length
              expect(dest_file_length).to eq(src_file_length)
            end
          end

          context 'when the source key has no file associated with it' do
            it 'does not attempt to copy over to the destination key' do
              expect {
                client.cp_file_between_keys('bogus', dest_key)
              }.to raise_error(CloudController::Blobstore::FileNotFound)

              expect(directory.files).to have(0).items
            end
          end

          context 'encryption' do
            let(:encryption) { 'my-algo' }
            let(:client) do
              described_class.new(connection_config: connection_config,
                                  directory_key: directory_key,
                                  encryption: encryption)
            end
            let(:dest_file) { double(:file, copy: true, save: true, nil?: false) }
            let(:src_file) { double(:file, copy: true, nil?: false) }

            before do
              allow_any_instance_of(FogClient).to receive(:file).with(src_key).and_return(src_file)
              allow_any_instance_of(FogClient).to receive(:file).with(dest_key).and_return(dest_file)
            end

            context 'when encryption type is specified' do
              it 'passes the encryption options to aws' do
                client.cp_file_between_keys(src_key, dest_key)
                options = { 'x-amz-server-side-encryption' => 'my-algo' }
                expect(src_file).to have_received(:copy).with('a-directory-key', 'xy/z7/xyz789', options)
              end
            end

            context 'when encryption type is not specified' do
              let(:encryption) { nil }

              it 'passes the encryption options to aws' do
                client.cp_file_between_keys(src_key, dest_key)
                expect(src_file).to have_received(:copy).with('a-directory-key', 'xy/z7/xyz789', {})
              end
            end
          end
        end

        describe '#delete_all' do
          let(:connection_config) { { provider: 'Local', local_root: local_dir } }

          before do
            Fog.unmock!
          end

          after do
            Fog.mock!
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

          it 'should be ok if there are no files' do
            expect(directory.files).to have(0).items
            expect {
              client.delete_all
            }.to_not raise_error
          end

          context 'when the underlying blobstore allows multiple deletes in a single request' do
            let(:connection_config) do
              {
                provider:              'AWS',
                aws_access_key_id:     'fake_access_key_id',
                aws_secret_access_key: 'fake_secret_access_key',
              }
            end

            it 'should be ok if there are no files' do
              Fog.mock!
              expect(directory.files).to have(0).items
              expect {
                client.delete_all
              }.to_not raise_error
            end

            it 'deletes in groups of the page_size' do
              Fog.mock!
              connection = client.send(:connection)
              allow(connection).to receive(:delete_multiple_objects)

              file = File.join(local_dir, 'empty_file')
              FileUtils.touch(file)

              client.cp_to_blobstore(file, 'abcdef1')
              client.cp_to_blobstore(file, 'abcdef2')
              client.cp_to_blobstore(file, 'abcdef3')
              expect(client.exists?('abcdef1')).to be_truthy
              expect(client.exists?('abcdef2')).to be_truthy
              expect(client.exists?('abcdef3')).to be_truthy

              page_size = 2
              client.delete_all(page_size)

              expect(connection).to have_received(:delete_multiple_objects).with(directory_key, ['ab/cd/abcdef1', 'ab/cd/abcdef2'])
              expect(connection).to have_received(:delete_multiple_objects).with(directory_key, ['ab/cd/abcdef3'])
            end
          end

          context 'when a root dir is provided' do
            let(:root_dir) { 'root-dir' }

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
          let(:connection_config) { { provider: 'Local', local_root: local_dir } }

          before do
            Fog.unmock!
          end

          after do
            Fog.mock!
          end

          it 'deletes all the files within a specific path' do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            remote_path_1 = 'aaaaguid'

            remote_key_1 = "#{remote_path_1}/stack_1"
            remote_key_2 = "#{remote_path_1}/stack_2"

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

          it 'should be ok if there are no files' do
            expect(directory.files).to have(0).items
            expect {
              client.delete_all_in_path('nonsense_path')
            }.to_not raise_error
          end

          context 'when the underlying blobstore allows multiple deletes in a single request' do
            let(:connection_config) do
              {
                provider:              'AWS',
                aws_access_key_id:     'fake_access_key_id',
                aws_secret_access_key: 'fake_secret_access_key',
              }
            end

            it 'should be ok if there are no files' do
              Fog.mock!
              expect(directory.files).to have(0).items
              expect {
                client.delete_all_in_path('path!')
              }.to_not raise_error
            end
          end

          context 'when a root dir is provided' do
            let(:root_dir) { 'root-dir' }

            it 'only deletes files at the root' do
              path = File.join(local_dir, 'empty_file')
              FileUtils.touch(path)

              remote_path_1 = 'aaaaguid'

              remote_key_1 = "#{remote_path_1}/stack_1"
              remote_key_2 = "#{remote_path_1}/stack_2"

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

          it "should be ok if the file doesn't exist" do
            expect(directory.files).to have(0).items
            expect {
              client.delete('non-existent-file')
            }.to_not raise_error
          end
        end

        describe '#delete_blob' do
          it "deletes the blob's file" do
            path = File.join(local_dir, 'empty_file')
            FileUtils.touch(path)

            client.cp_to_blobstore(path, 'abcdef123456')
            expect(client.exists?('abcdef123456')).to eq(true)

            blob = client.blob('abcdef123456')

            client.delete_blob(blob)
            expect(client.exists?('abcdef123456')).to eq(false)
          end

          it "should be ok if the file doesn't exist" do
            blob = FogBlob.new(nil, nil)
            expect {
              client.delete_blob(blob)
            }.to_not raise_error
          end
        end
      end

      context 'with root directory specified' do
        let(:root_dir) { 'my-root' }

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
            rescue
            end
          end
        end

        describe 'from a CDN' do
          let(:port) { 9875 } # TODO: Can we find a free port?
          let(:uri) { "http://localhost:#{port}" }
          let(:cdn) { Cdn.make(uri) }

          subject(:client) do
            described_class.new(connection_config: connection_config,
                                directory_key: directory_key,
                                cdn: cdn)
          end

          around(:each) do |example|
            WebMock.disable_net_connect!(allow_localhost: true)
            example.run
            WebMock.disable_net_connect!
          end

          it 'correctly downloads byte streams' do
            source_directory_path = File.expand_path('../../../../../fixtures/', File.dirname(__FILE__))
            source_file_path      = File.join(source_directory_path, 'pa/rt/partitioned_key')
            source_hexdigest      = Digest::SHA2.file(source_file_path).hexdigest

            pid = spawn("ruby -rwebrick -e'WEBrick::HTTPServer.new(:Port => #{port}, :DocumentRoot => \"#{source_directory_path}\").start'", out: 'test.out', err: 'test.err')

            begin
              Process.detach(pid)

              wait_for_server_to_accept_requests(uri)

              destination_file_path = File.join(Dir.mktmpdir, 'hard_file.xyz')

              client.download_from_blobstore('partitioned_key', destination_file_path)

              destination_hexdigest = Digest::SHA2.file(destination_file_path).hexdigest

              expect(destination_hexdigest).to eq(source_hexdigest)
            ensure
              Process.kill(9, pid)
            end
          end
        end

        describe 'from a blobstore' do
          let(:local_root) { File.expand_path('../../../../../', File.dirname(__FILE__)) }
          let(:connection_config) { { provider: 'Local', local_root: local_root } }
          let(:directory_key) { 'fixtures' }
          around(:each) do |example|
            Fog.unmock!
            example.run
            Fog.mock!
          end

          it 'correctly downloads byte streams' do
            Fog.unmock!
            source_directory_path = File.join(local_root, directory_key)

            source_file_path = File.join(source_directory_path, 'pa/rt/partitioned_key')
            source_hexdigest = Digest::SHA2.file(source_file_path).hexdigest

            destination_file_path = File.join(Dir.mktmpdir, 'hard_file.xyz')

            client.download_from_blobstore('partitioned_key', destination_file_path)

            destination_hexdigest = Digest::SHA2.file(destination_file_path).hexdigest

            expect(destination_hexdigest).to eq(source_hexdigest)
          end
        end
      end
    end
  end
end
