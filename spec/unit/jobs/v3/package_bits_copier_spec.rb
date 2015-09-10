require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    describe PackageBitsCopier do
      subject(:job) { PackageBitsCopier.new(source_package.guid, destination_package.guid) }

      let(:package_bits_path) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:blobstore_dir) { Dir.mktmpdir }
      let(:package_blobstore) do
        CloudController::Blobstore::Client.new({ provider: 'Local', local_root: blobstore_dir }, 'package')
      end
      let(:source_package) { PackageModel.make(type: 'bits', package_hash: 'something') }
      let(:destination_package) { PackageModel.make(type: 'bits') }

      before do
        Fog.unmock!
      end

      after do
        Fog.mock!
        FileUtils.remove_entry_secure blobstore_dir
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          package_blobstore.cp_to_blobstore(package_bits_path, source_package.guid)
        end

        it 'copies the source package zip to the package blob store for the destination package' do
          expect(package_blobstore.exists?(destination_package.guid)).to be_falsey

          job.perform

          expect(package_blobstore.exists?(destination_package.guid)).to be_truthy
        end

        it 'updates the destination package_hash and state' do
          expect(destination_package.package_hash).not_to eq(source_package.package_hash)
          expect(destination_package.state).not_to eq(VCAP::CloudController::PackageModel::READY_STATE)

          job.perform

          destination_package.reload
          expect(destination_package.package_hash).to eq(source_package.package_hash)
          expect(destination_package.state).to eq(VCAP::CloudController::PackageModel::READY_STATE)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:package_bits_copier)
        end

        context 'when the copy fails' do
          before do
            allow(package_blobstore).to receive(:cp_file_between_keys).and_raise('ba boom!')
          end

          it 'marks the package as failed and saves the message and raises the error' do
            expect(destination_package.error).not_to eq('failed to copy - ba boom!')
            expect(destination_package.state).not_to eq(VCAP::CloudController::PackageModel::FAILED_STATE)

            expect { job.perform }.to raise_error('ba boom!')

            destination_package.reload
            expect(destination_package.error).to eq('failed to copy - ba boom!')
            expect(destination_package.state).to eq(VCAP::CloudController::PackageModel::FAILED_STATE)
          end
        end

        context 'when the source package does not exist' do
          before { source_package.destroy }

          it 'marks the package as failed and saves the message and raises the error' do
            expect(destination_package.error).not_to eq('failed to copy - source package does not exist')
            expect(destination_package.state).not_to eq(VCAP::CloudController::PackageModel::FAILED_STATE)

            expect { job.perform }.to raise_error('source package does not exist')

            destination_package.reload
            expect(destination_package.error).to eq('failed to copy - source package does not exist')
            expect(destination_package.state).to eq(VCAP::CloudController::PackageModel::FAILED_STATE)
          end
        end

        context 'when the destination package does not exist' do
          before { destination_package.destroy }

          it 'marks the package as failed and saves the message and raises the error' do
            expect { job.perform }.to raise_error('destination package does not exist')
          end
        end
      end
    end
  end
end
