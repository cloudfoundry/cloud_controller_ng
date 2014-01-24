require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BuildpackBitsDelete do
      context "delays the blobstore delete" do
        let(:test_config) { config.dup }
        it "based on config" do
          test_config[:staging] = config[:staging].merge({max_staging_runtime: 10})

          Timecop.freeze do
            Delayed::Job.should_receive(:enqueue).with(an_instance_of(BlobstoreDelete),
              hash_including(run_at: Time.now + 10))
            BuildpackBitsDelete.delete_buildpack_in_blobstore("key", "blobstore", test_config)
          end
        end

        it "defaults to 120 when no config present" do
          test_config.delete(:staging)

          Timecop.freeze do
            Delayed::Job.should_receive(:enqueue).with(an_instance_of(BlobstoreDelete),
              hash_including(run_at: Time.now + 120))
            BuildpackBitsDelete.delete_buildpack_in_blobstore("key", "blobstore", test_config)
          end
        end
      end

      it 'does nothing if the key is nil' do
        Delayed::Job.should_not_receive(:enqueue)
        BuildpackBitsDelete.delete_buildpack_in_blobstore(nil, "blobstore", config)
      end
    end
  end
end