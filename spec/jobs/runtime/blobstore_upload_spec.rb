require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreUpload do
      let(:local_file) { Tempfile.new("tmpfile") }
      let(:blobstore_key) { "key" }
      let(:blobstore_name) { :droplet_blobstore }

      subject(:job) do
        BlobstoreUpload.new(local_file.path, blobstore_key, blobstore_name)
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      it "uploads the file to the blostore" do
        expect {
          job.perform
        }.to change {
          blobstore.exists?(blobstore_key)
        }.to(true)
      end

      it "cleans up the file at the end" do
        job.perform
        expect(File.exists?(local_file.path)).to be_false
      end

      it "cleans up the file even on error" do
        expect(blobstore).to receive(:cp_to_blobstore) { raise "UPLOAD FAILED" }

        expect { job.perform }.to raise_error

        expect(File.exists?(local_file.path)).to be_false
      end

      it "knows its job name" do
        expect(job.job_name).to equal(:blobstore_upload)
      end
    end
  end
end
