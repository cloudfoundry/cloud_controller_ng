require 'spec_helper'

module VCAP::CloudController
  describe BuildpackBitsDelete do
    let(:staging_timeout) { 144 }
    let(:key) { 'key' }
    let!(:blobstore) do
      CloudController::DependencyLocator.instance.buildpack_blobstore
    end

    let(:tmpfile) { Tempfile.new('') }

    before do
      blobstore.cp_to_blobstore(tmpfile.path, key)
    end

    after do
      tmpfile.delete
    end

    context 'delays the blobstore delete until staging completes' do
      it 'based on config' do
        Timecop.freeze do
          expect(Delayed::Job).to receive(:enqueue).with(an_instance_of(BlobstoreDelete),
                                                     hash_including(run_at: 144.seconds.from_now))
          BuildpackBitsDelete.delete_when_safe(key, staging_timeout)
        end
      end
    end

    it 'does nothing if the key is nil' do
      expect(Delayed::Job).not_to receive(:enqueue)
      BuildpackBitsDelete.delete_when_safe(nil, staging_timeout)
    end

    context 'when the blob exists' do
      it 'will create a job with attributes' do
        attrs = blobstore.blob(key).attributes
        job_attrs = {
          last_modified: attrs[:last_modified],
          etag: attrs[:etag]
        }

        expect(Jobs::Runtime::BlobstoreDelete).to receive(:new).with(key, :buildpack_blobstore, job_attrs).and_call_original
        BuildpackBitsDelete.delete_when_safe(key, staging_timeout)
      end
    end

    context 'when the blob does not exist' do
      it 'will not create a job' do
        blobstore.delete(key)

        expect(Jobs::Runtime::BlobstoreDelete).not_to receive(:new)
        BuildpackBitsDelete.delete_when_safe(key, staging_timeout)
      end
    end
  end
end
