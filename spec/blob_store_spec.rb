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

    describe "#cp_r_from_local" do
      let(:content) { "Some Nonsense" }
      let(:sha_of_nothing) { Digest::SHA1.hexdigest("") }
      let(:sha_of_content) { Digest::SHA1.hexdigest(content) }

      around do |example|
        FakeFS do
          Fog.unmock!
          example.call
          Fog.mock!
        end
      end

      let(:blob_store_dir) { Dir.mktmpdir }
      let(:local_dir) { Dir.mktmpdir }
      let(:blob_store) { BlobStore.new({ provider: "Local", local_root: blob_store_dir }, "a-directory-key") }

      it "ensure that the sha of nothing and sha of content are different for subsequent tests" do
        expect(sha_of_nothing[0..1]).not_to eq(sha_of_content[0..1])
      end

      it "copies the top-level local files into the blobstore" do
        FileUtils.touch(File.join(local_dir, "empty_file"))
        blob_store.cp_r_from_local(local_dir)

        expect(File.exists?(File.join(blob_store_dir, "a-directory-key", sha_of_nothing[0..1], sha_of_nothing[2..3], sha_of_nothing))).to be_true
        expect(Dir.entries(File.join(blob_store_dir, "a-directory-key"))).to have(3).items # [. .. $SHA]
      end

      it "recursively copies the local files into the blobstore" do
        subdir = File.join(local_dir, "subdir1", "subdir2")
        FileUtils.mkdir_p(subdir)
        File.open(File.join(subdir, "file_with_content"), "w") { |file| file.write(content) }

        blob_store.cp_r_from_local(local_dir)

        expect(File.exists?(File.join(blob_store_dir, "a-directory-key", sha_of_content[0..1], sha_of_content[2..3], sha_of_content))).to be_true
        expect(Dir.entries(File.join(blob_store_dir, "a-directory-key"))).to have(3).items # [. .. $SHA]
      end

      it "calls the fog with public false" do
        FileUtils.touch(File.join(local_dir, "empty_file"))
        blob_store.files.should_receive(:create).with(hash_including(public: false))
        blob_store.cp_r_from_local(local_dir)
      end

      context "when the file already exists in the blobstore" do
        it "does not reupload it" do
          FileUtils.touch(File.join(local_dir, "empty_file"))

          blob_store.files.should_receive(:create).once.and_call_original
          blob_store.cp_r_from_local(local_dir)
          blob_store.cp_r_from_local(local_dir)
        end
      end
    end
  end
end