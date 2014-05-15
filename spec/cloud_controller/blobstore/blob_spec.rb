require "spec_helper"

module CloudController
  module Blobstore
    describe Blob do
      subject(:blob) do
        Blob.new(file, cdn)
      end
      let(:file) { double("file", key: "abcdef") }
      let(:cdn) { double(:cdn) }

      context "it is backed by a CDN" do
        let(:url_from_cdn) { "http://some_distribution.cloudfront.net/ab/cd/abcdef" }

        before do
          cdn.stub(:download_uri).and_return(url_from_cdn)
        end

        it "returns a url to the cdn" do
          expect(blob.download_url).to eql(url_from_cdn)
        end
      end

      context "when is not backed by a CDN" do
        let(:cdn) { nil }

        context "a file responds to url" do
          before do
            file.stub(:url).and_return("http://example.com")
          end

          it "returns a url from file" do
            expect(blob.download_url).to eql("http://example.com")
          end

          it "is valid for an hour" do
            Timecop.freeze do
              now = Time.now
              expect(file).to receive(:url).with(now+3600)
              blob.download_url
            end
          end
        end

        context "a file does not respond to url" do
          before do
            file.stub(:url).and_return(nil)
            file.stub(:public_url).and_return("http://example.com/public")
            it "returns a public url from file" do
              expect(blob.download_url).to eql("http://example.com/public")
            end
          end
        end
      end

      describe "public_url" do
        it "comes from the file" do
          expect(file).to receive(:public_url).and_return("file_public_url")
          expect(blob.public_url).to eql("file_public_url")
        end
      end

      describe "local_path" do
        it "comes path of the file" do
          expect(file).to receive(:path).and_return("path")
          expect(blob.local_path).to eql("path")
        end
      end
    end
  end
end
