require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::BlobStore do
    describe "#local?" do
      it "is true if the provider is local" do
        blob_store = BlobStore.new({provider: "Local"}, "a-directory-key")
        expect(blob_store).to be_local
      end

      it "is false if the provider is not local" do
        blob_store = BlobStore.new({provider: "AWS"}, "a-directory-key")
        expect(blob_store).to_not be_local
      end
    end

    describe "#files" do
      before do
        Fog.unmock!
        @local_storage_dir = Dir.tmpdir
      end

      after do
        FileUtils.rm_rf(File.join @local_storage_dir, "a-directory-key")
        Fog.mock!
      end

      it "returns the files matching the directory key" do
        connection_config = {provider: "Local", local_root: @local_storage_dir}

        blob_store = BlobStore.new(connection_config, "a-directory-key")
        blob_store.files.create(key: "file-key-1", body: "file content", public: true)
        blob_store.files.create(key: "file-key-2", body: "file content", public: true)

        expect(blob_store.files).to have(2).items

        actual_directory_key = blob_store.files.first.directory.key
        expect(actual_directory_key).to eq("a-directory-key")
      end
    end
  end
end