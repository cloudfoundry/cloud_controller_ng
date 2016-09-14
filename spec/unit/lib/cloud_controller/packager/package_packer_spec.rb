require 'spec_helper'
require 'cloud_controller/packager/package_upload_handler'

module CloudController::Packager
  RSpec.describe PackageUploadHandler do
    subject(:packer) { described_class.new(package.guid, uploaded_files_path, cached_files_fingerprints) }

    let(:package) { VCAP::CloudController::PackageModel.make(state: VCAP::CloudController::PackageModel::PENDING_STATE) }
    let(:uploaded_files_path) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
    let(:cached_files_fingerprints) { [{ 'sha1' => 'abcde', 'fn' => 'lib.rb' }] }

    describe '#pack' do
      let(:packer_implementation) { instance_double(LocalBitsPacker, send_package_to_blobstore: expected_package_hash) }
      let(:expected_package_hash) { 'expected-package-hash' }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:packer).and_return(packer_implementation)
      end

      it 'uploads the package zip to the package blob store by delegating to a packing implementation' do
        packer.pack
        expect(packer_implementation).to have_received(:send_package_to_blobstore).with(package.guid, uploaded_files_path, cached_files_fingerprints)
      end

      it 'sets the package sha to the package' do
        expect {
          packer.pack
        }.to change { package.refresh.package_hash }.to(expected_package_hash)
      end

      it 'sets the state of the package' do
        expect {
          packer.pack
        }.to change { package.refresh.state }.to(VCAP::CloudController::PackageModel::READY_STATE)
      end

      it 'removes the compressed path afterwards' do
        expect(FileUtils).to receive(:rm_f).with(uploaded_files_path)
        packer.pack
      end

      it 'expires any old packages' do
        expect_any_instance_of(VCAP::CloudController::BitsExpiration).to receive(:expire_packages!)
        packer.pack
      end

      context 'when there is no package uploaded' do
        let(:uploaded_files_path) { nil }

        it 'doesn not try to remove the file' do
          expect(FileUtils).not_to receive(:rm_f)
          packer.pack
        end
      end

      context 'when the package no longer exists' do
        before do
          package.destroy
        end

        it 'raises an error and removes the compressed path' do
          expect(FileUtils).to receive(:rm_f).with(uploaded_files_path)
          expect { packer.pack }.to raise_error(PackageUploadHandler::PackageNotFound)
        end
      end

      context 'when sending the package to the blobstore fails' do
        let(:expected_error) { StandardError.new('failed to send') }
        before do
          allow(packer_implementation).to receive(:send_package_to_blobstore).and_raise(expected_error)
        end

        it 'sets the state of the package' do
          expect {
            packer.pack rescue StandardError
          }.to change { package.refresh.state }.to(VCAP::CloudController::PackageModel::FAILED_STATE)
        end

        it 'records the error on the package' do
          expect {
            packer.pack rescue StandardError
          }.to change { package.refresh.error }.to('failed to send')
        end

        it 're-raises the error' do
          expect {
            packer.pack
          }.to raise_error(expected_error)
        end
      end
    end
  end
end
