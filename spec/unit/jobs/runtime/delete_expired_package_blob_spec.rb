require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe DeleteExpiredPackageBlob do
      subject(:job) { described_class.new(package.guid) }
      let(:package) { PackageModel.make(package_hash: 'some-hash') }

      it { is_expected.to be_a_valid_job }

      it 'delegates to blobstore delete job' do
        expect_any_instance_of(BlobstoreDelete).to receive(:perform)
        job.perform
      end

      it 'nils the package_hash' do
        expect { job.perform }.to change { package.reload.package_hash }.to(nil)
      end

      context 'when the package does not exist' do
        let(:job) { described_class.new('phooey') }

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
