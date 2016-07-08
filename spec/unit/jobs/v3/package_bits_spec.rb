require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe PackageBits do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:package_guid) { SecureRandom.uuid }
      let(:fingerprints) { [:fingerprint] }

      subject(:job) do
        PackageBits.new(package_guid, uploaded_path, fingerprints)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:package_blobstore) { instance_double(CloudController::Blobstore::Client) }
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        it 'creates an AppBitsPackage and performs' do
          packer = instance_double(AppBitsPackage)
          expect(AppBitsPackage).to receive(:new).and_return(packer)
          expect(packer).to receive(:create_package_in_blobstore).with(package_guid, uploaded_path, an_instance_of(CloudController::Blobstore::FingerprintsCollection))
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:package_bits)
        end
      end
    end
  end
end
