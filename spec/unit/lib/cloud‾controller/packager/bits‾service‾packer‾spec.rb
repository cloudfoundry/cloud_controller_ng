require 'spec_helper'
require 'cloud_controller/packager/bits_service_packer'

module CloudController::Packager
  RSpec.describe BitsServicePacker do
    subject(:packer) { BitsServicePacker.new }

    let(:uploaded_files_path) { 'tmp/uploaded.zip' }
    let(:blobstore_key) { 'some-blobstore-key' }
    let(:cached_files_fingerprints) { [{ 'sha1' => 'abcde', 'fn' => 'lib.rb' }] }

    let(:package_blobstore) { double(:package_blobstore) }

    before do
      allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
        and_return(package_blobstore)
      allow(package_blobstore).to receive(:cp_to_blobstore)
    end

    describe '#send_package_to_blobstore' do
      it 'uploads the package to the bits service' do
        expect(package_blobstore).to receive(:cp_to_blobstore).
          with(uploaded_files_path, blobstore_key, resources: cached_files_fingerprints)
        packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
      end

      it 'returns the uploaded file hash' do
        expect(package_blobstore).to receive(:cp_to_blobstore).
          with(uploaded_files_path, blobstore_key, resources: cached_files_fingerprints).
          and_return({ sha1: 'abc', sha256: 'def' })
        result_hash = packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        expect(result_hash).to eq({ sha1: 'abc', sha256: 'def' })
      end

      context 'when uploading the package to the bits service fails' do
        let(:expected_exception) { StandardError.new('some error') }

        it 'raises the exception' do
          allow(package_blobstore).to receive(:cp_to_blobstore).and_raise(expected_exception)
          expect {
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          }.to raise_error(expected_exception)
        end
      end
    end
  end
end
