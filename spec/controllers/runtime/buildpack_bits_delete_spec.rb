require "spec_helper"

module VCAP::CloudController
  describe BuildpackBitsDelete do
    let(:staging_timeout) { 144 }

    context "delays the blobstore delete until staging completes" do
      it "based on config" do
        Timecop.freeze do
          Delayed::Job.should_receive(:enqueue).with(an_instance_of(BlobstoreDelete),
            hash_including(run_at: 144.seconds.from_now))
          BuildpackBitsDelete.delete_when_safe("key", "blobstore", staging_timeout)
        end
      end
    end

    it 'does nothing if the key is nil' do
      Delayed::Job.should_not_receive(:enqueue)
      BuildpackBitsDelete.delete_when_safe(nil, "blobstore", staging_timeout)
    end
  end
end