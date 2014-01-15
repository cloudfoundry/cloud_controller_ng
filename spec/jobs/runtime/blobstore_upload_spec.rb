require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreUpload do
      let(:local_file) { Tempfile.new("tmpfile") }
      let(:blobstore_key) { "key" }
      let(:blobstore_name) { :droplet_blobstore }

      subject do
        BlobstoreUpload.new(local_file.path, blobstore_key, blobstore_name)
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      it "uploads the file to the blostore" do
        expect {
          subject.perform
        }.to change {
          blobstore.exists?(blobstore_key)
        }.to(true)
      end

      it "cleans up the file at the end" do
        subject.perform
        expect(File.exists?(local_file.path)).to be_false
      end

      it "times out if the job takes longer than its timeout" do
        CloudController::DependencyLocator.stub(:instance) do
          sleep 2
        end

        subject.stub(:max_run_time).with(:blobstore_upload).and_return( 0.001 )

        expect {
          subject.perform
        }.to raise_error(Timeout::Error)
      end

      it "cleans up the file even on timeout" do
        CloudController::DependencyLocator.stub(:instance) do
          sleep 2
        end

        subject.stub(:max_run_time) { 1 }

        expect {
          subject.perform
        }.to raise_error(Timeout::Error)

        expect(File.exists?(local_file.path)).to be_false
      end
    end
  end
end
