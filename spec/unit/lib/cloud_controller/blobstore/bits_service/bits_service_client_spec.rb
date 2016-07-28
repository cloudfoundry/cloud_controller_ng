require 'spec_helper'
require_relative '../client_shared'

RSpec.describe BitsService::Client do
  let(:resource_type) { [:buildpacks, :droplets, :packages].sample }
  let(:resource_type_singular) { resource_type.to_s.singularize }
  let(:key) { SecureRandom.uuid }
  let(:private_resource_endpoint) { File.join(options[:private_endpoint], resource_type.to_s, key) }
  let(:public_resource_endpoint) { File.join(options[:public_endpoint], resource_type.to_s, key) }

  let(:file_path) do
    Tempfile.new('blob').tap do |file|
      file.write(SecureRandom.uuid)
      file.close
    end.path
  end
  let(:options) do
    {
      enabled: true,
      private_endpoint: 'http://bits-service.service.cf.internal',
      public_endpoint: 'http://bits-service.bosh-lite.com'
    }
  end

  subject(:client) { BitsService::Client.new(bits_service_options: options, resource_type: resource_type) }

  describe '#local?' do
    it 'is not local' do
      expect(client.local?).to be_falsey
    end
  end

  describe '#exists?' do
    context 'when the resource exists' do
      before do
        stub_request(:head, "http://bits-service.service.cf.internal/#{resource_type}/#{key}").to_return(status: 200)
      end

      it 'returns true' do
        expect(subject.exists?(key)).to be_truthy
      end
    end

    context 'when the resource does not exist' do
      before do
        stub_request(:head, "http://bits-service.service.cf.internal/#{resource_type}/#{key}").to_return(status: 404)
      end

      it 'returns false' do
        expect(subject.exists?(key)).to be_falsey
      end
    end

    context 'when the response code is invalid' do
      before do
        stub_request(:head, "http://bits-service.service.cf.internal/#{resource_type}/#{key}").to_return(status: 500)
      end

      it 'raises a BlobstoreError' do
        expect { subject.exists?(key) }.to raise_error(CloudController::Blobstore::BlobstoreError)
      end
    end
  end

  describe '#cp_to_blobstore' do
    it 'makes the correct request to the bits-service' do
      expect(VCAP::Request).to receive(:current_id).at_least(:twice).and_return('0815')
      request = stub_request(:put, private_resource_endpoint).
                with(body: /name="#{resource_type.to_s.singularize}"/).
                to_return(status: 201)

      subject.cp_to_blobstore(file_path, key)
      expect(request).to have_been_requested
    end

    context 'when the response code is not 201' do
      it 'raises a BlobstoreError' do
        stub_request(:put, private_resource_endpoint).to_return(status: 500)

        expect { subject.cp_to_blobstore(file_path, key) }.to raise_error(CloudController::Blobstore::BlobstoreError)
      end
    end
  end

  describe '#download_from_blobstore' do
    let(:destination_path) { "#{Dir.mktmpdir}/destination" }

    before do
      stub_request(:head, private_resource_endpoint).
        to_return(status: 200)
      stub_request(:get, private_resource_endpoint).
        to_return(status: 200, body: File.new(file_path))
    end

    it 'makes the correct request to the bits-service' do
      request = stub_request(:get, private_resource_endpoint).
                to_return(status: 200, body: File.new(file_path))

      subject.download_from_blobstore(key, destination_path)
      expect(request).to have_been_requested
    end

    it 'downloads the blob to the destination path' do
      expect {
        subject.download_from_blobstore(key, destination_path)
      }.to change { File.exist?(destination_path) }.from(false).to(true)
    end

    context 'when there is a redirect' do
      let(:redirected_location) { 'http://some.where/else' }
      before do
        stub_request(:head, private_resource_endpoint).
          to_return(status: 302, headers: { location: redirected_location })
      end

      it 'follows the redirect' do
        request = stub_request(:get, redirected_location).
                  to_return(status: 200, body: File.new(file_path))

        subject.download_from_blobstore(key, destination_path)
        expect(request).to have_been_requested
      end
    end

    context 'when mode is defined' do
      it 'sets the file to the given mode' do
        subject.download_from_blobstore(key, destination_path, mode: 0753)
        expect(sprintf('%o', File.stat(destination_path).mode)).to eq('100753')
      end
    end

    context 'when the response code is not 200' do
      it 'raises a BlobstoreError' do
        stub_request(:get, private_resource_endpoint).
          to_return(status: 500, body: File.new(file_path))

        expect {
          subject.download_from_blobstore(key, destination_path)
        }.to raise_error(CloudController::Blobstore::BlobstoreError)
      end
    end
  end

  context 'copying blobs between keys' do
    let(:destination_key) { SecureRandom.uuid }

    it 'downloads the blob before uploading it again with the new key' do
      stub_request(:head, private_resource_endpoint).to_return(status: 200)

      download_request = stub_request(:get, private_resource_endpoint).
                         to_return(status: 200, body: File.new(file_path))
      upload_request = stub_request(:put, File.join(options[:private_endpoint], resource_type.to_s, destination_key)).
                       with(body: /name="#{resource_type.to_s.singularize}";.*\r\n.*\r\n.*\r\n.*\r\n\r\n#{File.new(file_path).read}/).
                       to_return(status: 201)

      subject.cp_file_between_keys(key, destination_key)
      expect(download_request).to have_been_requested
      expect(upload_request).to have_been_requested
    end
  end

  describe '#delete' do
    it 'makes the correct request to the bits-service' do
      request = stub_request(:delete, private_resource_endpoint).
                to_return(status: 204)

      subject.delete(key)
      expect(request).to have_been_requested
    end

    context 'when the response code is 404' do
      it 'raises a NotFound error' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 404)

        expect {
          subject.delete(key)
        }.to raise_error(CloudController::Blobstore::FileNotFound)
      end
    end

    context 'when the response code is not 204' do
      it 'raises a BlobstoreError' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 500)

        expect {
          subject.delete(key)
        }.to raise_error(CloudController::Blobstore::BlobstoreError)
      end
    end
  end

  describe '#blob' do
    let(:private_endpoint_request) do
      stub_request(:head, private_resource_endpoint).to_return(status: 200)
    end
    let(:public_endpoint_request) do
      stub_request(:head, public_resource_endpoint).to_return(status: 200)
    end
    let(:blob) { subject.blob(key) }

    before do
      private_endpoint_request
      public_endpoint_request
    end

    it 'returns a blob object with the given guid' do
      expect(blob.guid).to eq(key)
    end

    it 'returns a blob object with public download_url' do
      expect(blob.public_download_url).to eq(public_resource_endpoint)
    end

    it 'returns a blob object with internal download_url' do
      expect(blob.internal_download_url).to eq(private_resource_endpoint)
    end

    context 'when the download urls result in a redirect' do
      let(:private_endpoint_request) do
        stub_request(:head, private_resource_endpoint).to_return(status: 302, headers: { location: 'some-redirect-1' })
      end
      let(:public_endpoint_request) do
        stub_request(:head, public_resource_endpoint).to_return(status: 302, headers: { location: 'some-redirect-2' })
      end

      it 'maps the redirected url as the internal_download_url' do
        expect(blob.internal_download_url).to eq('some-redirect-1')
      end

      it 'maps the redirected url as public_download_url' do
        expect(blob.public_download_url).to eq('some-redirect-2')
      end
    end
  end

  describe '#delete_blob' do
    before do
      stub_request(:head, private_resource_endpoint).to_return(status: 200)
      stub_request(:head, public_resource_endpoint).to_return(status: 200)
    end

    it 'sends the right request to the bits-service' do
      request = stub_request(:delete, private_resource_endpoint).to_return(status: 204)

      blob = subject.blob(key)
      subject.delete_blob(blob)

      expect(request).to have_been_requested
    end

    context 'when the response is not 204' do
      it 'raises a BlobstoreError' do
        stub_request(:delete, private_resource_endpoint).to_return(status: 500)

        expect {
          blob = subject.blob(key)
          subject.delete_blob(blob)
        }.to raise_error(CloudController::Blobstore::BlobstoreError)
      end
    end
  end

  describe '#delete_all' do
    it 'raises NotImplementedError' do
      expect {
        subject.delete_all
      }.to raise_error(NotImplementedError)
    end

    context 'when it is a buildpack_cache resource' do
      let(:resource_type) { :buildpack_cache }

      it 'sends the correct request to the bits-service' do
        request = stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries/')).to_return(status: 204)

        subject.delete_all
        expect(request).to have_been_requested
      end

      context 'when the response is not 204' do
        it 'raises a BlobstoreError' do
          stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries/')).to_return(status: 500)

          expect {
            subject.delete_all
          }.to raise_error(CloudController::Blobstore::BlobstoreError)
        end
      end
    end
  end

  describe '#delete_all_in_path' do
    it 'raises NotImplementedError' do
      expect {
        subject.delete_all_in_path('some-path')
      }.to raise_error(NotImplementedError)
    end

    context 'when it is a buildpack_cache resource' do
      let(:resource_type) { :buildpack_cache }

      it 'sends the correct request to the bits-service' do
        request = stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries', key)).to_return(status: 204)

        subject.delete_all_in_path(key)
        expect(request).to have_been_requested
      end

      context 'when the response is not 204' do
        it 'raises a BlobstoreError' do
          stub_request(:delete, File.join(options[:private_endpoint], 'buildpack_cache/entries', key)).to_return(status: 500)

          expect {
            subject.delete_all_in_path(key)
          }.to raise_error(CloudController::Blobstore::BlobstoreError)
        end
      end
    end
  end
end
