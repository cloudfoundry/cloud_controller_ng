require "spec_helper"

describe BlobStore do
  let(:content) { "Some Nonsense" }
  let(:sha_of_nothing) { Digest::SHA1.hexdigest("") }
  let(:sha_of_content) { Digest::SHA1.hexdigest(content) }
  let(:blob_store_dir) { Dir.mktmpdir }
  let(:local_dir) { Dir.mktmpdir }

  subject(:blob_store) { BlobStore.new({ provider: "Local", local_root: blob_store_dir }, "a-directory-key") }

  around do |example|
    FakeFS do
      Fog.unmock!
      example.call
      Fog.mock!
    end
  end

  describe "#local?" do
    it "is true if the provider is local" do
      blob_store = BlobStore.new({ provider: "Local" }, "a-directory-key")
      expect(blob_store).to be_local
    end

    it "is false if the provider is not local" do
      blob_store = BlobStore.new({ provider: "AWS" }, "a-directory-key")
      expect(blob_store).to_not be_local
    end
  end

  describe "#files" do
    it "returns the files matching the directory key" do
      blob_store.files.create(key: "file-key-1", body: "file content", public: true)
      blob_store.files.create(key: "file-key-2", body: "file content", public: true)

      expect(blob_store.files).to have(2).items

      actual_directory_key = blob_store.files.first.directory.key
      expect(actual_directory_key).to eq("a-directory-key")
    end
  end

  describe "#exists?" do
    it "exists if the file is there" do
      base_dir = File.join(blob_store_dir, "a-directory-key", sha_of_content[0..1], sha_of_content[2..3])
      FileUtils.mkdir_p(base_dir)
      File.open(File.join(base_dir, sha_of_content), "w") { |file| file.write(content) }

      expect(blob_store.exists?(sha_of_content)).to be_true
    end

    it "does not exist if not present" do
      expect(blob_store.exists?("foobar")).to be_false
    end
  end

  describe "#cp_r_from_local" do
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

  describe "#cp_to_local" do
    it "downloads the file, creating missing parent directories" do
      base_dir = File.join(blob_store_dir, "a-directory-key", sha_of_content[0..1], sha_of_content[2..3])
      FileUtils.mkdir_p(base_dir)
      File.open(File.join(base_dir, sha_of_content), "w") { |file| file.write(content) }

      destination = File.join(local_dir, "dir1", "dir2", "downloaded_file")
      expect(File.exists?(destination)).to be_false
      blob_store.cp_to_local(sha_of_content, destination)
      expect(File.exists?(destination)).to be_true
      expect(File.read(destination)).to eq(content)
    end
  end

  describe "#cp_from_local" do
    it "downloads the file, creating missing parent directories" do
      path = File.join(local_dir, "empty_file")
      FileUtils.touch(path)

      blob_store.cp_from_local(path, "abcdef123456")
      p Find.find(File.join(blob_store_dir)).to_a
      expect(File.exists?(File.join(blob_store_dir, "a-directory-key", "ab", "cd", "abcdef123456"))).to be_true
    end
  end
end
