require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreDelete do
      let(:key) { "key" }
      subject do
        BlobstoreDelete.new(key, :droplet_blobstore)
      end

      let!(:blobstore) do
        CloudController::DependencyLocator.instance.droplet_blobstore
      end

      let(:tmpfile) { Tempfile.new("")}

      before do
        CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
        blobstore.cp_to_blobstore(tmpfile.path, key)
      end

      it "deletes the blob blobstore" do
        expect {
          subject.perform
        }.to change {
          blobstore.exists?(key)
        }.from(true).to(false)
      end
    end
  end
end
