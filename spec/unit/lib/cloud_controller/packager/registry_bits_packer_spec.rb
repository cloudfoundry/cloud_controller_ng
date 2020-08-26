require 'spec_helper'
require 'cloud_controller/packager/registry_bits_packer'

module CloudController::Packager
  RSpec.describe RegistryBitsPacker do
    subject(:packer) { RegistryBitsPacker.new }

    let(:uploaded_files_path) { File.join(local_tmp_dir, 'good.zip') }
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:local_tmp_dir) { Dir.mktmpdir }
    let(:package_image_uploader_client) { instance_double(PackageImageUploader::Client) }
    let(:package_guid) { 'im-a-package-guid' }
    let(:registry) { 'hub.example.com/user' }

    before do
      TestConfig.override({ packages: { image_registry: { base_path: registry } } })
      allow(PackageImageUploader::Client).to receive(:new).and_return(package_image_uploader_client)
    end

    describe '#send_package_to_blobstore' do
      it 'uploads to the registry and returns the uploaded file hash' do
        expect(package_image_uploader_client).to receive(:post_package).
          with(package_guid, uploaded_files_path, registry).
          and_return('hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' })

        result_hash = packer.send_package_to_blobstore(package_guid, uploaded_files_path, [])
        expect(result_hash).to eq({ sha1: nil, sha256: 'sha-2-5-6-hex' })
      end

      context 'when uploading the package to the bits service fails' do
        let(:expected_exception) { StandardError.new('some error') }

        it 'raises the exception' do
          allow(package_image_uploader_client).to receive(:post_package).and_raise(expected_exception)
          expect {
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, [])
          }.to raise_error(expected_exception)
        end
      end
    end
  end
end
