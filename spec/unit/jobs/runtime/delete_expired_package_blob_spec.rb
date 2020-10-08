require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe DeleteExpiredPackageBlob, job_context: :worker do
      subject(:job) { DeleteExpiredPackageBlob.new(package.guid) }
      let(:package) { PackageModel.make(package_hash: 'some-hash', sha256_checksum: 'example-256-checksum') }

      it { is_expected.to be_a_valid_job }

      context 'when using a package registry' do
        let(:registry_delete) { instance_double(VCAP::CloudController::Jobs::Kubernetes::RegistryDelete) }

        before do
          TestConfig.override(packages: { image_registry: { base_path: 'hub.example.com/user' } })
          allow(VCAP::CloudController::Jobs::Kubernetes::RegistryDelete).to receive(:new).and_return(registry_delete)
          allow(registry_delete).to receive(:perform)
        end

        it 'delegates to registry delete job' do
          job.perform

          expect(VCAP::CloudController::Jobs::Kubernetes::RegistryDelete).to have_received(:new).with(package.bits_image_reference)
          expect(registry_delete).to have_received(:perform)
        end

        it 'nils the package_hash and sha256_checksum values' do
          expect { job.perform }.to change {
            [package.reload.package_hash, package.reload.sha256_checksum]
          }.to([nil, nil])
        end
      end

      context 'when not using a package registry' do
        it 'delegates to blobstore delete job' do
          expect_any_instance_of(BlobstoreDelete).to receive(:perform)
          job.perform
        end

        it 'nils the package_hash and sha256_checksum values' do
          expect { job.perform }.to change {
            [package.reload.package_hash, package.reload.sha256_checksum]
          }.to([nil, nil])
        end
      end

      context 'when the package does not exist' do
        let(:job) { DeleteExpiredPackageBlob.new('phooey') }

        it 'does not raise' do
          expect { job.perform }.not_to raise_error
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_expired_package_blob)
      end
    end
  end
end
