require "spec_helper"

module CloudController
  module Blobstore
    describe Client do
      let(:content) { "Some Nonsense" }
      let(:sha_of_content) { Digest::SHA1.hexdigest(content) }
      let(:local_dir) { Dir.mktmpdir }
      let(:directory_key) { "a-directory-key" }
      let(:connection_config) do
        {
          provider: "AWS",
          aws_access_key_id: 'fake_access_key_id',
          aws_secret_access_key: 'fake_secret_access_key',
        }
      end
      let(:min_size) { 20 }
      let(:max_size) { 50 }

      def upload_tmpfile(client, key="abcdef")
        Tempfile.open("") do |tmpfile|
          tmpfile.write(content)
          tmpfile.close
          client.cp_to_blobstore(tmpfile.path, key)
        end
      end

      after do
        Fog::Mock.reset
      end

      context "for a remote blobstore backed by a CDN" do
        subject(:client) do
          Client.new(connection_config, directory_key, cdn)
        end

        let(:cdn) { double(:cdn) }
        let(:url_from_cdn) { "http://some_distribution.cloudfront.net/ab/cd/abcdef" }
        let(:key) { "abcdef" }

        before do
          upload_tmpfile(client, key)
          cdn.stub(:download_uri).and_return(url_from_cdn)
        end

        it "is not local" do
          expect(client).to_not be_local
        end

        it "downloads through the CDN" do
          cdn.should_receive(:get).
            with("ab/cd/abcdef").
            and_yield("foobar").and_yield(" barbaz")

          destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

          expect { client.download_from_blobstore(key, destination) }.to change {
            File.exists?(destination)
          }.from(false).to(true)

          expect(File.read(destination)).to eq("foobar barbaz")
        end
      end

      context "a local blobstore" do
        subject(:client) do
          Client.new({provider: "Local"}, directory_key)
        end

        it "is true if the provider is local" do
          expect(client).to be_local
        end
      end

      context "common behaviors" do
        subject(:client) do
          Client.new(connection_config, directory_key)
        end

        context "with existing files" do
          before do
            upload_tmpfile(client, sha_of_content)
          end

          describe "#files" do
            it "returns a file saved in the blob store" do
              expect(client.files).to have(1).item
              expect(client.exists?(sha_of_content)).to be_true
            end

            it "uses the correct director keys when storing files" do
              actual_directory_key = client.files.first.directory.key
              expect(actual_directory_key).to eq(directory_key)
            end
          end

          describe "a file existence" do
            it "does not exist if not present" do
              different_content = "foobar"
              sha_of_different_content = Digest::SHA1.hexdigest(different_content)

              expect(client.exists?(sha_of_different_content)).to be_false

              upload_tmpfile(client, sha_of_different_content)

              expect(client.exists?(sha_of_different_content)).to be_true
              expect(client.blob(sha_of_different_content)).to be
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
            client.cp_r_to_blobstore(local_dir)
            expect(client.exists?(sha_of_nothing)).to be_true
          end

          it "recursively copies the local files into the blobstore" do
            subdir = File.join(local_dir, "subdir1", "subdir2")
            FileUtils.mkdir_p(subdir)
            File.open(File.join(subdir, "file_with_content"), "w") { |file| file.write(content) }

            client.cp_r_to_blobstore(local_dir)
            expect(client.exists?(sha_of_content)).to be_true
          end

          context "when the file already exists in the blobstore" do
            before do
              FileUtils.touch(File.join(local_dir, "empty_file"))
            end

            it "does not re-upload it" do
              client.cp_r_to_blobstore(local_dir)

              client.should_not_receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(local_dir)
            end
          end

          context "limit the file size" do
            let(:client) do
              Client.new(connection_config, directory_key, nil, nil, min_size, max_size)
            end

            it "does not copy files below the minimum size limit" do
              path = File.join(local_dir, "file_with_little_content")
              File.open(path, "w") { |file| file.write("a") }
              key = "987654321"

              client.should_not_receive(:exists)
              client.should_not_receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end

            it "does not copy files above the maximum size limit" do
              path = File.join(local_dir, "file_with_more_content")
              File.open(path, "w") { |file| file.write("an amount of content that is larger than the maximum limit") }
              key = "777777777"

              client.should_not_receive(:exists)
              client.should_not_receive(:cp_to_blobstore)
              client.cp_r_to_blobstore(path)
            end
          end

        end

        describe "returns a download uri" do
          context "when the blob store is a local" do
            subject(:client) do
              Client.new({provider: "Local", local_root: "/tmp"}, directory_key)
            end

            before do
              Fog.unmock!
            end

            after do
              Fog.mock!
            end

            it "does have a url" do
              upload_tmpfile(client)
              expect(client.download_uri("abcdef")).to match(%r{/ab/cd/abcdef})
            end
          end

          context "when not local" do
            before do
              upload_tmpfile(client)
              @uri = URI.parse(client.download_uri("abcdef"))
            end

            it "returns the correct uri to fetch a blob directly from amazon" do
              expect(@uri.scheme).to eql "https"
              expect(@uri.host).to eql "#{directory_key}.s3.amazonaws.com"
              expect(@uri.path).to eql "/ab/cd/abcdef"
            end

            it "returns nil for a non-existent key" do
              expect(client.download_uri("not-a-key")).to be_nil
            end
          end
        end

        describe "#download_from_blobstore" do
          context "when directly from the underlying storage" do
            before do
              upload_tmpfile(client, sha_of_content)
            end

            it "can download the file" do
              expect(client.exists?(sha_of_content)).to be_true
              destination = File.join(local_dir, "some_directory_to_place_file", "downloaded_file")

              expect { client.download_from_blobstore(sha_of_content, destination) }.to change {
                File.exists?(destination)
              }.from(false).to(true)

              expect(File.read(destination)).to eq(content)
            end
          end
        end

        describe "#cp_to_blobstore" do
          it "calls the fog with public false" do
            FileUtils.touch(File.join(local_dir, "empty_file"))
            client.files.should_receive(:create).with(hash_including(public: false))
            client.cp_to_blobstore(local_dir, "empty_file")
          end

          it "uploads the files with the specified key" do
            path = File.join(local_dir, "empty_file")
            FileUtils.touch(path)

            client.cp_to_blobstore(path, "abcdef123456")
            expect(client.exists?("abcdef123456")).to be_true
            expect(client.files).to have(1).item
          end

          it "defaults to private files" do
            path = File.join(local_dir, "empty_file")
            FileUtils.touch(path)
            key = "abcdef12345"

            client.cp_to_blobstore(path, key)
            expect(client.blob(key).public_url).to be_nil
          end

          it "can copy as a public file" do
            client.stub(:local?) { true }
            path = File.join(local_dir, "empty_file")
            FileUtils.touch(path)
            key = "abcdef12345"

            client.cp_to_blobstore(path, key)
            expect(client.blob(key).public_url).to be
          end

          context "limit the file size" do
            let(:client) do
              Client.new(connection_config, directory_key, nil, nil, min_size, max_size)
            end

            it "does not copy files below the minimum size limit" do
              path = File.join(local_dir, "file_with_little_content")
              File.open(path, "w") { |file| file.write("a") }
              key = "987654321"

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be_false
            end

            it "does not copy files above the maximum size limit" do
              path = File.join(local_dir, "file_with_more_content")
              File.open(path, "w") { |file| file.write("an amount of content that is larger than the maximum limit") }
              key = "777777777"

              client.cp_to_blobstore(path, key)
              expect(client.exists?(key)).to be_false
            end
          end
        end

        describe "#delete" do
          it "deletes the file" do
            path = File.join(local_dir, "empty_file")
            FileUtils.touch(path)

            client.cp_to_blobstore(path, "abcdef123456")
            expect(client.exists?("abcdef123456")).to be_true
            client.delete("abcdef123456")
            expect(client.exists?("abcdef123456")).to be_false
          end

          it "should be ok if the file doesn't exist" do
            expect(client.files).to have(0).items
            expect {
              client.delete("non-existent-file")
            }.to_not raise_error
          end
        end
      end

      context "with root directory specified" do
        subject(:client) do
          Client.new(connection_config, directory_key, nil, "my-root")
        end

        it "includes the directory in the partitioned key" do
          upload_tmpfile(client, "abcdef")
          expect(client.exists?("abcdef")).to be_true
          expect(client.blob("abcdef")).to be
          expect(client.download_uri("abcdef")).to match(%r{my-root/ab/cd/abcdef})
        end
      end
    end
  end
end
