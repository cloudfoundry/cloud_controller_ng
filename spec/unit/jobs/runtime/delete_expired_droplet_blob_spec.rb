require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe DeleteExpiredDropletBlob do
      subject(:job) { described_class.new(droplet.guid) }
      let(:droplet) { DropletModel.make }

      it { is_expected.to be_a_valid_job }

      it 'delegates to blobstore delete job' do
        expect_any_instance_of(BlobstoreDelete).to receive(:perform)
        job.perform
      end

      it 'nils the droplet checksums' do
        expect { job.perform }.to change { [droplet.reload.droplet_hash, droplet.reload.sha256_checksum] }.to([nil, nil])
      end

      context 'when the droplet does not exist' do
        let(:job) { described_class.new('phooey') }

        it 'does not raise' do
          expect { job.perform }.not_to raise_error
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_expired_droplet_blob)
      end
    end
  end
end
