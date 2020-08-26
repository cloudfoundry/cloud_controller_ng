require 'spec_helper'
require 'package_image_uploader/client'

module PackageImageUploader
  RSpec.describe Client do
    let(:package_image_uploader_host) { '127.0.0.1' }
    let(:package_image_uploader_port) { 8080 }
    subject { PackageImageUploader::Client.new(package_image_uploader_host, package_image_uploader_port) }

    describe '#post_package' do
      let(:status) { 200 }
      let(:response) { '{}' }

      before do
        stub_request(:post, "http://#{package_image_uploader_host}:#{package_image_uploader_port}/packages").
          with(body: {
            'package_zip_path' => '/path/to/package.zip',
            'package_guid' => 'a-package-guid',
            'registry_base_path' => 'docker.io/cfcapidocker'
          }).to_return(status: status, body: response)
      end

      context 'when the request succeeds' do
        let(:status) { 200 }
        let(:response) { '{"hash":{"algorithm":"sha256","hex":"sha-2-5-6-hex"}}' }

        it 'returns the OCI Image sha' do
          expect(subject.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker')).to eq(
            'hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' }
          )
        end
      end

      context 'when PackageImageUploader returns a 422' do
        let(:status) { 422 }
        let(:response) { 'unprocessable entity' }

        it 'raises a PackageImageUploader::Error' do
          expect { subject.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(PackageImageUploader::Error, /Unprocessable Entity error/)
        end
      end

      context 'when PackageImageUploader returns a 400' do
        let(:status) { 400 }
        let(:response) { 'bad request' }

        it 'raises a PackageImageUploader::Error' do
          expect { subject.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(PackageImageUploader::Error, /Bad Request error/)
        end
      end

      context 'when PackageImageUploader returns a 500' do
        let(:status) { 500 }
        let(:response) { 'bad response' }

        it 'raises a PackageImageUploader::Error' do
          expect { subject.post_package('a-package-guid', '/path/to/package.zip', 'docker.io/cfcapidocker') }.
            to raise_error(PackageImageUploader::Error, /Server error/)
        end
      end
    end
  end
end
