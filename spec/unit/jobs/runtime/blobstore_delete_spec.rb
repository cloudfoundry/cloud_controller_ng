require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreDelete do
      let(:key) { 'key' }
      subject(:job) do
        BlobstoreDelete.new(key, :droplet_blobstore)
      end

      let!(:blobstore) do
        CloudController::DependencyLocator.instance.droplet_blobstore
      end

      let(:tmpfile) { Tempfile.new('') }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(blobstore)
        blobstore.cp_to_blobstore(tmpfile.path, key)
      end

      after do
        tmpfile.delete
      end

      it { is_expected.to be_a_valid_job }

      context 'when no attributes defined' do
        it 'deletes the blob' do
          expect {
            job.perform
          }.to change {
            blobstore.exists?(key)
          }.from(true).to(false)
        end
      end

      context 'when attributes match' do
        it 'deletes the blob' do
          blob = blobstore.blob(key)
          job.attributes = blob.attributes

          expect {
            job.perform
          }.to change {
            blobstore.exists?(key)
          }.from(true).to(false)
        end
      end

      context 'when attributes do not match' do
        let(:job) do
          BlobstoreDelete.new(key, :droplet_blobstore, { 'mis' => 'match' })
        end

        it 'does not delete the blob' do
          expect {
            job.perform
          }.to_not change {
            blobstore.exists?(key)
          }
        end
      end

      context 'when the blob does not exist' do
        it 'does not invoke delete' do
          expect(blobstore).to receive(:blob).and_return(nil)
          job.perform
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:blobstore_delete)
      end
    end
  end
end
