require "spec_helper"

describe Blobstore do
  let(:content) { "Some Nonsense" }
  let(:sha_of_content) { Digest::SHA1.hexdigest(content) }
  let(:local_dir) { Dir.mktmpdir }
  let(:directory_key) { "a-directory-key" }

  def upload_tmpfile(blobstore, key="abcdef")
    Tempfile.open("") do |tmpfile|
      tmpfile.write(content)
      tmpfile.close
      blobstore.cp_to_blobstore(tmpfile.path, key)
    end
  end

  after do
    Fog::Mock.reset
  end

  context "for a remote blobstore backed by a CDN" do
    let(:cdn) { double(:cdn) }
    let(:cdn_blobstore) do
      Blobstore.new(
          {
              provider: "AWS",
              aws_access_key_id: 'fake_access_key_id',
              aws_secret_access_key: 'fake_secret_access_key',
          }, directory_key, cdn)
    end

    let(:url_from_cdn) do
      "http://some_distribution.cloudfront.net/ab/cd/abcdef"
    end

    let(:key) { "abcdef" }

    before do
      upload_tmpfile(cdn_blobstore, key)
      cdn.stub(:download_uri).and_return(url_from_cdn)
    end

    it "is not local" do
      expect(cdn_blobstore).to_not be_local
    end

    it "returns a url to the cdn" do
      expect(cdn_blobstore.download_uri("abcdef")).to eql(url_from_cdn)
    end

    it "downloads through the CDN" do
      cdn.should_receive(:get).
          with("ab/cd/abcdef").
          and_yield("foobar").and_yield(" barbaz")

      destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

      expect { cdn_blobstore.download_from_blobstore(key, destination) }.to change {
        File.exists?(destination)
      }.from(false).to(true)

      expect(File.read(destination)).to eq("foobar barbaz")
    end
  end

  context "a local blobstore" do
    it "is true if the provider is local" do
      blobstore = Blobstore.new({provider: "Local"}, directory_key)
      expect(blobstore).to be_local
    end
  end

  shared_examples "a blobstore" do
    context "common behaviors" do
      context "with existing files" do
        before do
          upload_tmpfile(blobstore, sha_of_content)
        end

        describe "#files" do
          it "returns a file saved in the blob store" do
            expect(blobstore.files).to have(1).item
            expect(blobstore.exists?(sha_of_content)).to be_true
          end

          it "uses the correct director keys when storing files" do
            actual_directory_key = blobstore.files.first.directory.key
            expect(actual_directory_key).to eq(directory_key)
          end
        end

        describe "a file existence" do
          it "does not exist if not present" do
            different_content = "foobar"
            sha_of_different_content = Digest::SHA1.hexdigest(different_content)

            expect(blobstore.exists?(sha_of_different_content)).to be_false

            upload_tmpfile(blobstore, sha_of_different_content)

            expect(blobstore.exists?(sha_of_different_content)).to be_true
            expect(blobstore.file(sha_of_different_content)).to be
          end
        end
      end

      describe "#cp_r_to_blobstore" do
        let(:sha_of_nothing) { Digest::SHA1.hexdigest("") }

        it "ensure that the sha of nothing and sha of content are different for subsequent tests" do
          expect(sha_of_nothing[0..1]).not_to eq(sha_of_content[0..1])
        end

        it "copies the top-level local files into the blobstore" do
          FileUtils.touch(File.join(local_dir, "empty_file"))
          blobstore.cp_r_to_blobstore(local_dir)
          expect(blobstore.exists?(sha_of_nothing)).to be_true
        end

        it "recursively copies the local files into the blobstore" do
          subdir = File.join(local_dir, "subdir1", "subdir2")
          FileUtils.mkdir_p(subdir)
          File.open(File.join(subdir, "file_with_content"), "w") { |file| file.write(content) }

          blobstore.cp_r_to_blobstore(local_dir)
          expect(blobstore.exists?(sha_of_content)).to be_true
        end

        context "when the file already exists in the blobstore" do
          before do
            FileUtils.touch(File.join(local_dir, "empty_file"))
          end

          it "does not re-upload it" do
            expect(blobstore.exists?(sha_of_content)).to be_false
            blobstore.cp_r_to_blobstore(local_dir)
            blobstore.cp_r_to_blobstore(local_dir)
          end
        end
      end

      describe "returns a download uri" do
        context "when the blob store is a local" do
          around do |instance|
            Fog.unmock!
            instance.run
            Fog.mock!
          end

          subject(:local_blobstore) do
            Blobstore.new({provider: "Local", local_root: "/tmp"}, directory_key)
          end

          it "does have a public url" do
            upload_tmpfile(local_blobstore)
            expect(local_blobstore.download_uri("abcdef")).to match(%r{/ab/cd/abcdef})
          end
        end

        context "when not local" do
          before do
            upload_tmpfile(blobstore)
            @uri = URI.parse(blobstore.download_uri("abcdef"))
          end

          it "returns the correct uri to fetch a blob directly from amazon" do
            expect(@uri.scheme).to eql "https"
            expect(@uri.path).to eql "/ab/cd/abcdef"
          end

          it "is valid for an hour" do
            match_data = (/Expires=(\d+)/).match @uri.query
            expect(match_data[1].to_i).to be_within(100).of((Time.now + 3600).to_i)
          end

          it "returns nil for a non-existent key" do
            expect(blobstore.download_uri("not-a-key")).to be_nil
          end
        end
      end

      describe "#download_from_blobstore" do
        context "when directly from the underlying storage" do
          before do
            upload_tmpfile(blobstore, sha_of_content)
          end

          it "can download the file" do
            expect(blobstore.exists?(sha_of_content)).to be_true
            destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

            expect { blobstore.download_from_blobstore(sha_of_content, destination) }.to change {
              File.exists?(destination)
            }.from(false).to(true)

            expect(File.read(destination)).to eq(content)
          end
        end
      end

      describe "#cp_r_to_blobstore" do
        it "calls the fog with public false" do
          FileUtils.touch(File.join(local_dir, "empty_file"))
          blobstore.files.should_receive(:create).with(hash_including(public: false))
          blobstore.cp_r_to_blobstore(local_dir)
        end

        it "uploads the files with the specified key" do
          path = File.join(local_dir, "empty_file")
          FileUtils.touch(path)

          blobstore.cp_to_blobstore(path, "abcdef123456")
          expect(blobstore.exists?("abcdef123456")).to be_true
          expect(blobstore.files).to have(1).item
        end

        it "defaults to private files" do
          path = File.join(local_dir, "empty_file")
          FileUtils.touch(path)
          key = "abcdef12345"

          blobstore.cp_to_blobstore(path, key)
          expect(blobstore.file(key).public_url).to be_nil
        end

        it "can copy as a public file" do
          blobstore.stub(:local?) { true }
          path = File.join(local_dir, "empty_file")
          FileUtils.touch(path)
          key = "abcdef12345"

          blobstore.cp_to_blobstore(path, key)
          expect(blobstore.file(key).public_url).to be
        end
      end

      describe "#delete" do
        it "deletes the file" do
          path = File.join(local_dir, "empty_file")
          FileUtils.touch(path)

          blobstore.cp_to_blobstore(path, "abcdef123456")
          expect(blobstore.exists?("abcdef123456")).to be_true
          blobstore.delete("abcdef123456")
          expect(blobstore.exists?("abcdef123456")).to be_false
        end

        it "should be ok if the file doesn't exist" do
          expect(blobstore.files).to have(0).items
          expect {
            blobstore.delete("non-existent-file")
          }.to_not raise_error
        end
      end

      describe "#dir" do
        before do
          @storage = Fog::Storage.new(s3_blobstore_config)
          @connection = Fog::Storage.new(s3_blobstore_config)
          @directories = double('directories')
          
          allow(@directories).to receive(:get) { 
            @storage.directories.get(directory_key) 
          }
          allow(@directories).to receive(:create) {
            @storage.directories.create(:key => directory_key, :public => false) 
          }
          allow(@connection).to receive(:directories) { @directories }
          allow(blobstore).to receive(:connection) {@connection}
        end

        context "single blobstore instance" do
          it "should create directory once" do
            expect(@directories).to receive(:get).once
            expect(@directories).to receive(:create).once
            3.times do
              blobstore.files
            end
          end
        end

        context "multiple blobstore instances" do
          let(:otherBlobstore) {
            otherBlobstore = Blobstore.new(s3_blobstore_config, directory_key)
            allow(otherBlobstore).to receive(:connection) {@connection}
            otherBlobstore
          }

          it "should create directory once" do
            expect(@directories).to receive(:get).twice
            expect(@directories).to receive(:create).once

            blobstore.files
            otherBlobstore.files
          end
        end
      end  
    end
  end

  context "an S3 blobstore" do
    let(:s3_blobstore_config) do
      {                        
        provider: "AWS",
        aws_access_key_id: 'fake_access_key_id',
        aws_secret_access_key: 'fake_secret_access_key',
      }
    end
    
    context "default region" do
      subject(:blobstore) { Blobstore.new(s3_blobstore_config, directory_key) }
      it_behaves_like "a blobstore"

      describe "returns a download uri" do
        context "when not local" do
          before do
            upload_tmpfile(blobstore)
            @uri = URI.parse(blobstore.download_uri("abcdef"))
          end

          it "returns the correct uri to fetch a blob directly from amazon" do
            expect(@uri.host).to eql "#{directory_key}.s3.amazonaws.com"
          end
        end
      end
    end

    context "non-default region" do
      let(:region) {"eu-west-1"}
      let(:s3_blobstore_config) do
        { 
          provider: "AWS",
          aws_access_key_id: 'fake_access_key_id',
          aws_secret_access_key: 'fake_secret_access_key',
          region: region
        } 
      end
      subject(:blobstore) do
        Blobstore.new(s3_blobstore_config, directory_key) 
      end

      it_behaves_like "a blobstore"

      describe "returns a download uri" do
        context "when not local" do
          before do
            upload_tmpfile(blobstore)
            @uri = URI.parse(blobstore.download_uri("abcdef"))
          end

          it "returns the correct uri to fetch a blob directly from amazon" do
            expect(@uri.host).to eql "#{directory_key}.s3-#{region}.amazonaws.com"
          end
        end
      end
    end
  end

  context "with root directory specified" do
    subject(:blobstore) do
      Blobstore.new({
                        provider: "AWS",
                        aws_access_key_id: 'fake_access_key_id',
                        aws_secret_access_key: 'fake_secret_access_key',
                    }, directory_key, nil, "my-root")
    end

    it "includes the directory in the partitioned key" do
      upload_tmpfile(blobstore, "abcdef")
      expect(blobstore.exists?("abcdef")).to be_true
      expect(blobstore.file("abcdef")).to be
      expect(blobstore.download_uri("abcdef")).to match(%r{my-root/ab/cd/abcdef})
    end
  end
end