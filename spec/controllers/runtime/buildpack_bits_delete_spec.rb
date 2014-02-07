require "spec_helper"

module VCAP::CloudController
  describe BuildpackBitsDelete do
    context "delays the blobstore delete until staging completes" do
      let(:test_config) { config.dup }
      it "based on config" do
        test_config[:staging] = config[:staging].merge({max_staging_runtime: 10.seconds})

        Timecop.freeze do
          Delayed::Job.should_receive(:enqueue).with(an_instance_of(BlobstoreDelete),
            hash_including(run_at: 10.seconds.from_now))
          BuildpackBitsDelete.delete_when_safe("key", "blobstore", test_config)
        end
      end

      it "defaults to 120 seconds when no config present" do
        test_config.delete(:staging)

        Timecop.freeze do
          Delayed::Job.should_receive(:enqueue).with(an_instance_of(BlobstoreDelete),
            hash_including(run_at: 120.seconds.from_now))
          BuildpackBitsDelete.delete_when_safe("key", "blobstore", test_config)
        end
      end
    end

    it 'does nothing if the key is nil' do
      Delayed::Job.should_not_receive(:enqueue)
      BuildpackBitsDelete.delete_when_safe(nil, "blobstore", config)
    end
  end
end