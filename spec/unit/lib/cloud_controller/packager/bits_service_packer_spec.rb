require 'spec_helper'
require 'cloud_controller/packager/bits_service_packer'

module CloudController::Packager
  RSpec.describe BitsServicePacker do
    subject(:packer) { described_class.new }

    let(:uploaded_files_path) { 'tmp/uploaded.zip' }
    let(:blobstore_key) { 'some-blobstore-key' }
    let(:cached_files_fingerprints) { [{ 'sha1' => 'abcde', 'fn' => 'lib.rb' }] }

    let(:package_blobstore) { double(:package_blobstore) }
    let(:receipt) { [{ 'sha1' => '12345', 'fn' => 'app.rb' }] }
    let(:package_file) { Tempfile.new('package') }
    let(:resource_pool) { double(BitsService::ResourcePool) }

    before do
      allow_any_instance_of(CloudController::DependencyLocator).to receive(:bits_service_resource_pool).
        and_return(resource_pool)
      allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
        and_return(package_blobstore)
      allow(resource_pool).to receive(:upload_entries).
        and_return(double(:response, code: 201, body: receipt.to_json))
      allow(resource_pool).to receive(:bundles).
        and_return(double(:response, code: 200, body: 'contents'))
      allow(package_blobstore).to receive(:cp_to_blobstore)
      allow(Tempfile).to receive(:new).and_return(package_file)
    end

    describe '#send_package_to_blobstore' do
      it 'uses the resource_pool to upload the zip file' do
        expect(resource_pool).to receive(:upload_entries).with(uploaded_files_path)
        packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
      end

      it 'merges the bits-service receipt with the cli resources to ask for the bundles' do
        merged_fingerprints = cached_files_fingerprints + receipt
        expect(resource_pool).to receive(:bundles).
          with(merged_fingerprints.to_json)
        packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
      end

      it 'uploads the package to the bits service' do
        expect(package_blobstore).to receive(:cp_to_blobstore) do |package_path, guid|
          expect(File.read(package_path)).to eq('contents')
          expect(guid).to eq(blobstore_key)
        end.and_return(double(Net::HTTPCreated))
        packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
      end

      it 'returns the uploaded file hash' do
        result_hash = packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        expect(result_hash).to eq({
          sha1:   Digester.new.digest_file(package_file),
          sha256: Digester.new(algorithm: Digest::SHA256).digest_file(package_file),
        })
      end

      shared_examples 'a packaging failure' do
        let(:expected_exception) { ::CloudController::Errors::ApiError }

        it 'raises the exception' do
          expect {
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          }.to raise_error(expected_exception)
        end
      end

      context 'when no new bits are being uploaded' do
        let(:uploaded_files_path) { nil }

        it 'does not upload new entries to the bits service' do
          expect(resource_pool).to_not receive(:upload_entries)
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        end

        it 'downloads a bundle with the original fingerprints' do
          expect(resource_pool).to receive(:bundles).with(cached_files_fingerprints.to_json)
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        end

        it 'uploads the package to the bits service' do
          expect(package_blobstore).to receive(:cp_to_blobstore) do |package_path, guid|
            expect(File.read(package_path)).to eq('contents')
            expect(guid).to eq(blobstore_key)
          end
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        end

        it 'returns the correct package hash in the app' do
          result_hash = packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          expect(result_hash).to eq({
            sha1:   Digester.new.digest_file(package_file),
            sha256: Digester.new(algorithm: Digest::SHA256).digest_file(package_file),
          })
        end
      end

      context 'when `upload_entries` fails' do
        before do
          allow(resource_pool).to receive(:upload_entries).
            and_raise(BitsService::Errors::UnexpectedResponseCode)
        end

        it_behaves_like 'a packaging failure'
      end

      context 'when `bundles` fails' do
        before do
          allow(resource_pool).to receive(:bundles).
            and_raise(BitsService::Errors::UnexpectedResponseCode)
        end

        it_behaves_like 'a packaging failure'
      end

      context 'when writing the package to a temp file fails' do
        let(:expected_exception) { StandardError.new('some error') }

        before do
          allow(Tempfile).to receive(:new).
            and_raise(expected_exception)
        end

        it_behaves_like 'a packaging failure'
      end

      context 'when uploading the package to the bits service fails' do
        let(:expected_exception) { StandardError.new('some error') }

        before do
          allow(package_blobstore).to receive(:cp_to_blobstore).and_raise(expected_exception)
        end

        it_behaves_like 'a packaging failure'
      end

      context 'when the bits service has an internal error on upload_entries' do
        before do
          allow(resource_pool).to receive(:upload_entries).
            and_raise(BitsService::Errors::UnexpectedResponseCode)
        end

        it_behaves_like 'a packaging failure'
      end

      context 'when the bits service has an internal error on bundles' do
        before do
          allow(resource_pool).to receive(:bundles).
            and_raise(BitsService::Errors::UnexpectedResponseCode)
        end

        it_behaves_like 'a packaging failure'
      end
    end
  end
end
