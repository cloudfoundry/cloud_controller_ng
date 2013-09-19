require "spec_helper"

describe BlobStore do
  let(:content) { "Some Nonsense" }
  let(:sha_of_nothing) { Digest::SHA1.hexdigest("") }
  let(:sha_of_content) { Digest::SHA1.hexdigest(content) }
  let(:blob_store_dir) { Dir.mktmpdir }
  let(:local_dir) { Dir.mktmpdir }
  let(:directory_key) { "a-directory-key" }
  let(:cdn) { double(:cdn) }
  let(:cdn_blob_store) do
    BlobStore.new({
      provider: "AWS",
      aws_access_key_id: 'fake_access_key_id',
      aws_secret_access_key: 'fake_secret_access_key',
    }, directory_key, cdn)
  end

  def make_tmpfile(contents)
    tmpfile = Tempfile.new("")
    tmpfile.write(contents)
    tmpfile.close
    tmpfile
  end

  after do
    Fog::Mock.reset
  end

  subject(:blob_store) do
    BlobStore.new({
                    provider: "AWS",
                    aws_access_key_id: 'fake_access_key_id',
                    aws_secret_access_key: 'fake_secret_access_key',
                  }, directory_key)
  end

  describe "#local?" do
    it "is true if the provider is local" do
      blob_store = BlobStore.new({ provider: "Local" }, directory_key)
      expect(blob_store).to be_local
    end

    it "is false if the provider is not local" do
      blob_store = BlobStore.new({ provider: "AWS" }, directory_key)
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
        expect(actual_directory_key).to eq(directory_key)
      end
    end

    describe "a file existence" do
      it "does not exist if not present" do
        different_content = "foobar"
        sha_of_different_content = Digest::SHA1.hexdigest(different_content)

        expect(blob_store.exists?(sha_of_different_content)).to be_false
        tmpfile = make_tmpfile(different_content)
        blob_store.cp_from_local(tmpfile.path, sha_of_different_content)
        expect(blob_store.exists?(sha_of_different_content)).to be_true
        expect(blob_store.file(sha_of_different_content)).to be
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
        blob_store.cp_r_from_local(local_dir)
        blob_store.cp_r_from_local(local_dir)
      end
    end
  end

  describe "partitioning" do
    it "partitions by two pairs of consectutive characters from the sha" do
      expect(blob_store.partitioned_key("abcdef")).to eql "ab/cd/abcdef"
    end
  end

  describe "returns a download uri" do
    def upload_tmpfile(blob_store)
      tmpfile = make_tmpfile(content)
      blob_store.cp_from_local(tmpfile.path, "abcdef")
    end

    context "when the blob store is a local" do
      around do |instance|
        Fog.unmock!
        instance.run
        Fog.mock!
      end

      subject(:local_blob_store) do
        BlobStore.new({ provider: "Local", local_root: "/tmp" }, directory_key)
      end

      it "does have a public url" do
        upload_tmpfile(local_blob_store)
        expect(local_blob_store.download_uri("abcdef")).to match(%r{/ab/cd/abcdef})
      end
    end

    context "when not local" do
      before do
        upload_tmpfile(blob_store)
        @uri = URI.parse(blob_store.download_uri("abcdef"))
      end

      it "returns the correct uri to fetch a blob directly from amazon" do
        expect(@uri.scheme).to eql "https"
        expect(@uri.host).to eql "#{directory_key}.s3.amazonaws.com"
        expect(@uri.path).to eql "/ab/cd/abcdef"
      end

      it "is valid for an hour" do
        match_data = (/Expires=(\d+)/).match @uri.query
        expect(match_data[1].to_i).to be_within(100).of((Time.now + 3600).to_i)
      end

      it "returns nil for a non-existent key" do
        expect(blob_store.download_uri("not-a-key")).to be_nil
      end

      context "with a CDN" do
        let(:url_from_cdn) do
          "http://some_distribution.cloudfront.net/ab/cd/abcdef"
        end
        before do
          upload_tmpfile(cdn_blob_store)
          cdn.stub(:download_uri).and_return(url_from_cdn)
        end

        it "returns a url to the cdn" do
          expect(cdn_blob_store.download_uri("abcdef")).to eql(url_from_cdn)
        end
      end
    end
  end

  describe "#cp_to_local" do
    context "when from a cdn" do
      it "downloads through the CDN" do
        cdn.should_receive(:get).
          with(cdn_blob_store.partitioned_key(sha_of_content)).
          and_yield("foobar").and_yield(" barbaz")

        destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

        expect { cdn_blob_store.cp_to_local(sha_of_content, destination) }.to change {
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

        expect { blob_store.cp_to_local(sha_of_content, destination) }.to change {
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

    it "defaults to private files" do
      path = File.join(local_dir, "empty_file")
      FileUtils.touch(path)
      key = "abcdef12345"

      blob_store.cp_from_local(path, key)
      expect(blob_store.file(key).public_url).to be_nil
    end

    it "can copy a public file" do
      path = File.join(local_dir, "empty_file")
      FileUtils.touch(path)
      key = "abcdef12345"

      blob_store.cp_from_local(path, key, true)
      expect(blob_store.file(key).public_url).to be
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

  context "with root directory specified" do
    subject(:blob_store) do
      BlobStore.new({
                      provider: "AWS",
                      aws_access_key_id: 'fake_access_key_id',
                      aws_secret_access_key: 'fake_secret_access_key',
                    }, directory_key, nil, "my-root")

    end

    it "" do
      tmpfile = make_tmpfile(content)
      blob_store.cp_from_local(tmpfile.path, "abcdef123456")
      expect(blob_store.exists?("abcdef123456")).to be_true
      expect(blob_store.file("abcdef123456")).to be
      expect(blob_store.download_uri("abcdef123456")).to match(%r{my-root/ab/cd/abcdef})
    end
  end
end
