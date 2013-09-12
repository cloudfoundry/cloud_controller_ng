require "spec_helper"

describe BlobStore do
  let(:content) { "Some Nonsense" }
  let(:sha_of_nothing) { Digest::SHA1.hexdigest("") }
  let(:sha_of_content) { Digest::SHA1.hexdigest(content) }
  let(:blob_store_dir) { Dir.mktmpdir }
  let(:local_dir) { Dir.mktmpdir }

  def make_tmpfile(contents)
    tmpfile = Tempfile.new("")
    tmpfile.write(contents)
    tmpfile.close
    tmpfile
  end

  after do
    Fog::Mock.reset
  end

  subject(:blob_store) { BlobStore.new({
                                         provider: "AWS",
                                         aws_access_key_id: 'fake_access_key_id',
                                         aws_secret_access_key: 'fake_secret_access_key',
                                       }, "a-directory-key") }

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


  context 'with existing files' do

    before do
      @tmpfile = make_tmpfile(content)
      blob_store.cp_from_local(@tmpfile.path, sha_of_content)
    end

    after do
      @tmpfile.unlink
    end

    describe "#files" do
      it "returns a file saved in the blob store" do
        expect(blob_store.files).to have(1).item
        expect(blob_store.exists?(sha_of_content)).to be_true
      end


      it "uses the correct director keys when storing files" do
        actual_directory_key = blob_store.files.first.directory.key
        expect(actual_directory_key).to eq("a-directory-key")
      end
    end

    describe "#exists?" do
      it "does not exist if not present" do
        different_content = "foobar"
        sha_of_different_content = Digest::SHA1.hexdigest(different_content)

        expect(blob_store.exists?(sha_of_different_content)).to be_false
        tmpfile = make_tmpfile(different_content)
        blob_store.cp_from_local(tmpfile.path, sha_of_different_content)
        expect(blob_store.exists?(sha_of_different_content)).to be_true
      end
    end
  end

  describe "#cp_r_from_local" do
    it "ensure that the sha of nothing and sha of content are different for subsequent tests" do
      expect(sha_of_nothing[0..1]).not_to eq(sha_of_content[0..1])
    end

    it "copies the top-level local files into the blobstore" do
      FileUtils.touch(File.join(local_dir, "empty_file"))
      blob_store.cp_r_from_local(local_dir)
      expect(blob_store.exists?(sha_of_nothing)).to be_true
    end

    it "recursively copies the local files into the blobstore" do
      subdir = File.join(local_dir, "subdir1", "subdir2")
      FileUtils.mkdir_p(subdir)
      File.open(File.join(subdir, "file_with_content"), "w") { |file| file.write(content) }

      blob_store.cp_r_from_local(local_dir)
      expect(blob_store.exists?(sha_of_content)).to be_true
    end

    context "when the file already exists in the blobstore" do
      before do
        FileUtils.touch(File.join(local_dir, "empty_file"))
      end

      it "does not reupload it" do
        expect(blob_store.exists?(sha_of_content)).to be_false
        #blob_store.files.should_receive(:create).once.and_call_original
        blob_store.cp_r_from_local(local_dir)
        blob_store.cp_r_from_local(local_dir)
      end
    end
  end

  describe "partitioning" do
    it "partitions by two pairs of consectutive characters from the sha" do
      expect(blob_store.key_from_sha1("abcdef")).to eql "ab/cd/abcdef"
    end
  end

  describe "#cp_to_local" do
    context "when from a cdn" do
      let(:cdn) { double(:cdn) }

      subject(:blob_store) { BlobStore.new({ provider: "Local", local_root: blob_store_dir }, "a-directory-key", cdn) }

      it "downloads through the CDN" do
        cdn.should_receive(:get).
          with(blob_store.key_from_sha1(sha_of_content)).
          and_yield("foobar").and_yield(" barbaz")

        destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

        expect { blob_store.cp_to_local(sha_of_content, destination)}.to change {
          File.exists?(destination)
        }.from(false).to(true)

        expect(File.read(destination)).to eq("foobar barbaz")
      end
    end

    context "when directly from the underlying storage" do
      before do
        tmpfile = make_tmpfile(content)
        blob_store.cp_from_local(tmpfile, sha_of_content)
      end
      it "downloads the file" do
        expect(blob_store.exists?(sha_of_content)).to be_true
        destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

        expect { blob_store.cp_to_local(sha_of_content, destination)}.to change {
          File.exists?(destination)
        }.from(false).to(true)

        expect(File.read(destination)).to eq(content)
      end
    end
  end

  describe "#cp_from_local" do
    it "calls the fog with public false" do
      FileUtils.touch(File.join(local_dir, "empty_file"))
      blob_store.files.should_receive(:create).with(hash_including(public: false))
      blob_store.cp_r_from_local(local_dir)
    end

    it "uploads the files with the specified key" do
      path = File.join(local_dir, "empty_file")
      FileUtils.touch(path)

      blob_store.cp_from_local(path, "abcdef123456")
      expect(blob_store.exists?("abcdef123456")).to be_true
    end
  end

  describe "#delete" do
    it "deletes the file" do
      path = File.join(local_dir, "empty_file")
      FileUtils.touch(path)

      blob_store.cp_from_local(path, "abcdef123456")
      expect(blob_store.exists?("abcdef123456")).to be_true
      blob_store.delete("abcdef123456")
      expect(blob_store.exists?("abcdef123456")).to be_false
    end

    it "should be ok if the file doesn't exist" do
      expect(blob_store.files).to have(0).items
      expect {
        blob_store.delete("non-existant-file")
      }.to_not raise_error
    end
  end
end
