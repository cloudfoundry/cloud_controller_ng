require 'spec_helper'
require_relative '../client_shared_spec'

module CloudController
  module Blobstore
    describe DavClient do
      subject(:client) { DavClient.new(options, directory_key) }
      let(:response) { instance_double(HTTP::Message) }
      let(:httpclient) { instance_double(HTTPClient) }
      let(:options) do
        {
          endpoint: 'http://localhost',
          secret:   'some-secret'
        }
      end
      let(:directory_key) { 'droplets' }

      before do
        allow(HTTPClient).to receive_messages(new: httpclient)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(DavBlob, url: nil) }
        before do
          allow(httpclient).to receive_messages(head: instance_double(HTTP::Message, status: 200))
          allow(httpclient).to receive_messages(put: instance_double(HTTP::Message, status: 201))
          allow(httpclient).to receive_messages(get: instance_double(HTTP::Message, status: 200))
          allow(httpclient).to receive_messages(delete: instance_double(HTTP::Message, status: 204))
          allow(httpclient).to receive_messages(request: instance_double(HTTP::Message, status: 201))
        end

        it_behaves_like 'a blobstore client'
      end

      describe 'basic auth' do
        before do
          options.merge!(user: 'username', password: 'top-sekret')
        end

        it 'adds Authorization header when there is a user and password' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          client.exists?('foobar')

          expect(httpclient).to have_received(:head).with(anything, header: { 'Authorization' => 'Basic dXNlcm5hbWU6dG9wLXNla3JldA==' })
        end
      end

      describe '#exists?' do
        it 'should return true for an object that already exists' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          expect(client.exists?('foobar')).to be(true)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'should return false for an object that does not exist' do
          allow(response).to receive_messages(status: 404)
          allow(httpclient).to receive_messages(head: response)

          expect(client.exists?('foobar')).to be(false)
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'should raise a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')
          allow(httpclient).to receive_messages(head: response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object existence/
          expect(httpclient).to have_received(:head).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end
      end

      describe '#download_from_blobstore' do
        let(:destination_path) { Dir::Tmpname.make_tmpname(Dir.tmpdir, nil) }

        after do
          File.delete(destination_path) if File.exist?(destination_path)
        end

        it 'should fetch an object' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive(:get).and_yield('content').and_return(response)

          client.download_from_blobstore('foobar', destination_path)

          expect(File.read(destination_path)).to eq('content')
          expect(httpclient).to have_received(:get).with('http://localhost/admin/droplets/fo/ob/foobar', {}, {})
        end

        it 'should raise an exception when there is an error fetching an object' do
          allow(response).to receive_messages(status: 500, content: 'error message')
          allow(httpclient).to receive_messages(get: response)

          expect { client.download_from_blobstore('foobar', destination_path) }.to raise_error BlobstoreError, /Could not fetch object/
          expect(httpclient).to have_received(:get).with('http://localhost/admin/droplets/fo/ob/foobar', {}, {})
        end

        describe 'file permissions' do
          context 'when not specifying a mode' do
            it 'does not change permissions on the file' do
              allow(response).to receive_messages(status: 200)
              allow(httpclient).to receive(:get).and_yield('content').and_return(response)

              client.download_from_blobstore('foobar', destination_path)

              expect(sprintf('%o', File.stat(destination_path).mode)).to eq('100644')
            end
          end

          context 'when specifying a mode' do
            it 'does change permissions on the file' do
              allow(response).to receive_messages(status: 200)
              allow(httpclient).to receive(:get).and_yield('content').and_return(response)

              client.download_from_blobstore('foobar', destination_path, mode: 0753)

              expect(sprintf('%o', File.stat(destination_path).mode)).to eq('100753')
            end
          end
        end
      end

      describe '#cp_to_blobstore' do
        let!(:tmpfile) do
          Tempfile.open('') do |tmpfile|
            tmpfile.write(content)
            tmpfile
          end
        end
        let(:content) { 'file content' }

        after do
          tmpfile.unlink
        end

        it 'should create an object' do
          allow(response).to receive_messages(status: 201, content: '')

          expect(httpclient).to receive(:put) do |*args|
            uri, body, _ = args
            expect(uri).to eq('http://localhost/admin/droplets/fo/ob/foobar')
            expect(body).to be_kind_of(File)
            expect(body.read).to eq('file content')
            response
          end

          client.cp_to_blobstore(tmpfile.path, 'foobar')
        end

        it 'should overwrite an existing file' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive(:put).and_return(response)

          expect(httpclient).to receive(:put) do |*args|
            uri, body, _ = args
            expect(uri).to eq('http://localhost/admin/droplets/fo/ob/foobar')
            expect(body).to be_kind_of(File)
            expect(body.read).to eq('file content')
            response
          end

          client.cp_to_blobstore(tmpfile.path, 'foobar')
        end

        it 'should raise an exception when there is an error creating an object' do
          allow(response).to receive_messages(status: 500, content: nil)
          allow(httpclient).to receive_messages(put: response)

          expect { client.cp_to_blobstore(tmpfile.path, 'foobar') }.to raise_error BlobstoreError, /Could not create object/
        end

        describe 'retries' do
          context 'when retries is 0' do
            let(:retries) { 0 }

            it 'fails if the underlying operation fails' do
              allow(response).to receive_messages(status: 500, content: nil)
              allow(httpclient).to receive_messages(put: response)

              expect { client.cp_to_blobstore(tmpfile.path, 'foobar', retries) }.to raise_error BlobstoreError, /Could not create object/
            end
          end

          context 'when retries is greater than zero' do
            let(:retries) { 1 }

            context 'and the underlying blobstore eventually succeeds' do
              let(:response_success) { double(HTTP::Message) }

              it 'succeeds' do
                allow(response).to receive_messages(status: 500, content: nil)
                allow(response_success).to receive_messages(status: 201, content: '')
                allow(httpclient).to receive(:put).and_return(response, response_success)

                expect { client.cp_to_blobstore(tmpfile.path, 'foobar', retries) }.not_to raise_error
              end
            end

            context 'and the underlying blobstore fails more than the requested number of retries' do
              it 'fails' do
                allow(response).to receive_messages(status: 500, content: nil)
                allow(httpclient).to receive_messages(put: response)

                expect { client.cp_to_blobstore(tmpfile.path, 'foobar', retries) }.to raise_error BlobstoreError, /Could not create object/
              end
            end
          end
        end

        describe 'file size limits' do
          subject(:client) { DavClient.new(options, directory_key, min_size, max_size) }
          let(:min_size) { 20 }
          let(:max_size) { 50 }

          context 'too small file' do
            let(:content) { 'a' * (min_size - 1) }

            it 'does not copy files below the minimum size limit' do
              allow(httpclient).to receive_messages(put: nil)

              client.cp_to_blobstore(tmpfile.path, 'foobar')

              expect(httpclient).not_to have_received(:put)
            end
          end

          context 'too large file' do
            let(:content) { 'a' * (max_size + 1) }

            it 'does not copy files above the maximum size limit' do
              allow(httpclient).to receive_messages(put: nil)

              client.cp_to_blobstore(tmpfile.path, 'foobar')

              expect(httpclient).not_to have_received(:put)
            end
          end
        end
      end

      describe '#cp_r_to_blobstore' do
        let(:source_dir) { Dir.mktmpdir }
        let!(:tmpfile1) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('file 1')
            tmpfile
          end
        end
        let!(:tmpfile2) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('file 2')
            tmpfile
          end
        end
        let(:tmpfile1_sha) { Digester.new.digest_path(tmpfile1.path) }
        let(:tmpfile2_sha) { Digester.new.digest_path(tmpfile2.path) }
        let(:nested_dir) { Dir.mkdir(File.join(source_dir, 'nested')) }
        let!(:nested_tmpfile1) do
          Tempfile.open('', source_dir) do |tmpfile|
            tmpfile.write('nested file 1')
            tmpfile
          end
        end
        let(:nested_tmpfile1_sha) { Digester.new.digest_path(nested_tmpfile1.path) }

        before do
          allow(httpclient).to receive_messages(head: instance_double(HTTP::Message, status: 404))
        end

        after do
          FileUtils.rm_rf(source_dir)
        end

        it 'should upload all the files in the directory and nested directories' do
          allow(response).to receive_messages(status: 201, content: '')
          allow(httpclient).to receive(:put).and_return(response)

          client.cp_r_to_blobstore(source_dir)

          expect(httpclient).to have_received(:put).thrice
          expect(httpclient).to have_received(:put).with(
            "http://localhost/admin/droplets/#{tmpfile1_sha[0..1]}/#{tmpfile1_sha[2..3]}/#{tmpfile1_sha}", a_kind_of(File), {})
          expect(httpclient).to have_received(:put).with("http://localhost/admin/droplets/#{tmpfile2_sha[0..1]}/#{tmpfile2_sha[2..3]}/#{tmpfile2_sha}", a_kind_of(File), {})
          expect(httpclient).to have_received(:put).with(
            "http://localhost/admin/droplets/#{nested_tmpfile1_sha[0..1]}/#{nested_tmpfile1_sha[2..3]}/#{nested_tmpfile1_sha}", a_kind_of(File), {})
        end

        context 'when a file already exists in the blobstore' do
          before do
            success_response = instance_double(HTTP::Message, status: 200)
            allow(httpclient).to receive(:head).with(/#{nested_tmpfile1_sha}/, anything).and_return(success_response)
          end

          it 'does not re-upload it' do
            allow(response).to receive_messages(status: 201, content: '')
            allow(httpclient).to receive(:put).and_return(response)

            client.cp_r_to_blobstore(source_dir)

            expect(httpclient).to have_received(:put).twice
            expect(httpclient).not_to have_received(:put).with(
              "http://localhost/admin/droplets/#{nested_tmpfile1_sha[0..1]}/#{nested_tmpfile1_sha[2..3]}/#{nested_tmpfile1_sha}", a_kind_of(File), {})
          end
        end

        describe 'file size limits' do
          subject(:client) { DavClient.new(options, directory_key, min_size, max_size) }
          let(:min_size) { 20 }
          let(:max_size) { 50 }

          context 'too small file' do
            let!(:small_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                tmpfile.write('a' * (min_size - 1))
                tmpfile
              end
            end
            let(:small_file_sha) { Digester.new.digest_path(small_file.path) }

            it 'does not copy files below the minimum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).not_to have_received(:put).with(
                "http://localhost/admin/droplets/#{small_file_sha[0..1]}/#{small_file_sha[2..3]}/#{small_file_sha}", a_kind_of(File), {})
            end
          end

          context 'too large file' do
            let!(:large_file) do
              Tempfile.open('', source_dir) do |tmpfile|
                tmpfile.write('a' * (max_size + 1))
                tmpfile
              end
            end
            let(:large_file_sha) { Digester.new.digest_path(large_file.path) }

            it 'does not copy files above the maximum size limit' do
              allow(response).to receive_messages(status: 201, content: '')
              allow(httpclient).to receive(:put).and_return(response)

              client.cp_r_to_blobstore(source_dir)

              expect(httpclient).not_to have_received(:put).with(
                "http://localhost/admin/droplets/#{large_file_sha[0..1]}/#{large_file_sha[2..3]}/#{large_file_sha}", a_kind_of(File), {})
            end
          end
        end
      end

      describe '#cp_file_between_keys' do
        it 'copies the file from the source key to the destination key' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive(:request).and_return(response)

          client.cp_file_between_keys('foobar', 'bazbar')

          expect(httpclient).to have_received(:request) do |*args|
            method, uri, _, _, headers = args
            expect(method).to eq(:copy)
            expect(uri).to eq('http://localhost/admin/droplets/fo/ob/foobar')
            expect(headers).to match(hash_including('Destination' => 'http://localhost/admin/droplets/ba/zb/bazbar'))
          end
        end

        it 'should raise an exception when there is an error copying an object' do
          allow(response).to receive_messages(status: 500, content: '')
          allow(httpclient).to receive(:request).and_return(response)

          expect { client.cp_file_between_keys('foobar', 'bazbar') }.to raise_error BlobstoreError, /Could not copy object/
        end

        context 'when the source key has no file associated with it' do
          it 'raises a FileNotFound Error' do
            allow(response).to receive_messages(status: 404, content: 'Not Found')
            allow(httpclient).to receive(:request).and_return(response)

            expect {
              client.cp_file_between_keys('foobar', 'bazbar')
            }.to raise_error(CloudController::Blobstore::FileNotFound, /Could not find object 'foobar'/)
          end
        end
      end

      describe '#delete' do
        it 'should delete an object' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive(:delete).and_return(response)

          client.delete('foobar')

          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'should raise FileNotFound error when the file is not found in blobstore during deleting' do
          allow(response).to receive_messages(status: 404, content: 'Not Found')
          allow(httpclient).to receive(:delete).and_return(response)

          expect {
            client.delete('foobar')
          }.to raise_error CloudController::Blobstore::FileNotFound, /Could not find object 'foobar'/
        end

        it 'should raise an exception when there is an error deleting an object' do
          allow(response).to receive_messages(status: 500, content: '')
          expect(httpclient).to receive(:delete).and_return(response)

          expect { client.delete('foobar') }.to raise_error BlobstoreError, /Could not delete object/
        end
      end

      describe '#delete_all' do
        let(:delete_response) { instance_double(HTTP::Message, status: 204, content: '') }
        let(:mkcol_response) { instance_double(HTTP::Message, status: 201, content: '') }

        it 'deletes the collection and then recreates the collection' do
          allow(delete_response).to receive_messages(status: 404, content: 'Not Found')
          allow(httpclient).to receive(:delete).and_return(delete_response)
          allow(httpclient).to receive(:request).and_return(mkcol_response)

          client.delete_all

          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/', header: {})
          expect(httpclient).to have_received(:request) do |*args|
            method, uri, _, _, headers = args
            expect(method).to eq(:mkcol)
            expect(uri).to eq('http://localhost/admin/droplets/')
            expect(headers).to eq({})
          end
        end
      end

      describe '#delete_all_in_path' do
      end

      describe '#blob' do
        it 'returns a blob' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          blob = client.blob('foobar')

          expect(blob).to be_a(DavBlob)
        end

        it 'returns nil if there is no object at the key' do
          allow(response).to receive_messages(status: 404)
          allow(httpclient).to receive_messages(head: response)

          blob = client.blob('foobar')

          expect(blob).to be_nil
        end

        it 'raises a BlobstoreError if response status is neither 200 nor 404' do
          allow(response).to receive_messages(status: 500, content: '')
          allow(httpclient).to receive_messages(head: response)

          expect { client.exists?('foobar') }.to raise_error BlobstoreError, /Could not get object/
        end
      end

      describe '#delete_blob' do
        it 'deletes the blobs key' do
          allow(response).to receive_messages(status: 204, content: '')
          allow(httpclient).to receive_messages(delete: response)
          blob = DavBlob.new(httpmessage: instance_double(HTTPClient), url: 'http://localhost/admin/droplets/fo/ob/foobar', secret: 'some-secret')

          client.delete_blob(blob)

          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end

        it 'does not error if the object is already deleted' do
          allow(response).to receive_messages(status: 404, content: 'Not Found')
          allow(httpclient).to receive_messages(delete: response)
          blob = DavBlob.new(httpmessage: instance_double(HTTPClient), url: 'http://localhost/admin/droplets/fo/ob/foobar', secret: 'some-secret')

          expect { client.delete_blob(blob) }.not_to raise_error
          expect(httpclient).to have_received(:delete).with('http://localhost/admin/droplets/fo/ob/foobar', header: {})
        end
      end

      describe '#download_uri' do
        it 'returns the correct uri to fetch a blob directly from the blobstore' do
          allow(response).to receive_messages(status: 200)
          allow(httpclient).to receive_messages(head: response)

          uri = URI(client.download_uri('foobar'))

          expect(uri.scheme).to eql 'http'
          expect(uri.host).to eql 'localhost'
          expect(uri.path).to eql '/read/droplets/fo/ob/foobar'
          expect(uri.query).to include('expires=')
          expect(uri.query).to include('md5=')
        end

        it 'returns nil for a non-existent key' do
          allow(response).to receive_messages(status: 404)
          allow(httpclient).to receive_messages(head: response)

          expect(client.download_uri('not-a-key')).to be_nil
        end
      end
    end
  end
end
