require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BitsServicePacker do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:package) { PackageModel.make(state: PackageModel::PENDING_STATE) }
      let(:package_blobstore) { double(:package_blobstore) }
      let(:receipt) { [{ 'sha1' => '12345', 'fn' => 'app.rb' }] }
      let(:fingerprints) { [{ 'sha1' => 'abcde', 'fn' => 'lib.rb' }] }
      let(:package_file) { Tempfile.new('package') }
      let(:resource_pool) { double(BitsService::ResourcePool) }

      subject(:packer) do
        BitsServicePacker.new(package.guid, uploaded_path, fingerprints)
      end

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

      describe '#perform' do
        it 'uses the resource_pool to upload the zip file' do
          expect(resource_pool).to receive(:upload_entries).with(uploaded_path)
          packer.perform
        end

        it 'merges the bits-service receipt with the cli resources to ask for the bundles' do
          merged_fingerprints = fingerprints + receipt
          expect(resource_pool).to receive(:bundles).
            with(merged_fingerprints.to_json)
          packer.perform
        end

        it 'uploads the package to the bits service' do
          expect(package_blobstore).to receive(:cp_to_blobstore) do |package_path, guid|
            expect(File.read(package_path)).to eq('contents')
            expect(guid).to eq(package.guid)
          end.and_return(double(Net::HTTPCreated))
          packer.perform
        end

        it 'logs an error if the package cannot be found' do
          package.destroy

          logger = double(:logger, error: nil, info: nil)
          allow(packer).to receive(:logger).and_return(logger)

          packer.perform

          expect(logger).to have_received(:error).with("Package not found: #{package.guid}")
        end

        it 'sets the correct package hash on the package and marks the package as successfully uploaded' do
          packer.perform
          expect(package.reload.package_hash).to eq(Digester.new.digest_file(package_file))
          expect(package.state).to eq(PackageModel::READY_STATE)
        end

        shared_examples 'a packaging failure' do
          let(:expected_exception) { ::CloudController::Errors::ApiError }

          it 'marks the app as failed to stage' do
            packer.perform rescue expected_exception
            expect(package.reload.state).to eq(PackageModel::FAILED_STATE)
          end

          it 'raises the exception' do
            expect {
              packer.perform
            }.to raise_error(expected_exception)
          end
        end

        context 'when no new bits are being uploaded' do
          let(:uploaded_path) { nil }

          it 'does not upload new entries to the bits service' do
            expect(resource_pool).to_not receive(:upload_entries)
            packer.perform
          end

          it 'downloads a bundle with the original fingerprints' do
            expect(resource_pool).to receive(:bundles).with(fingerprints.to_json)
            packer.perform
          end

          it 'uploads the package to the bits service' do
            expect(package_blobstore).to receive(:cp_to_blobstore) do |package_path, guid|
              expect(File.read(package_path)).to eq('contents')
              expect(guid).to eq(package.guid)
            end
            packer.perform
          end

          it 'sets the correct package hash in the app' do
            packer.perform
            expect(package.reload.package_hash).to eq(Digester.new.digest_file(package_file))
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
end
