require "spec_helper"
require "cloud_controller/blob_store/cdn"

describe Cdn do
  let(:cdn_host) { "https://some_distribution.cloudfront.net"}
  let(:cdn) { Cdn.new(cdn_host) }

  describe "#get" do
    let(:path_location) { "ab/cd/abcdefghi" }

    context "when CloudFront Signer is not configured" do
      before do
        AWS::CF::Signer.stub(:is_configured?).and_return(false)
        @stub = stub_request(:get, "#{cdn_host}/#{path_location}").to_return(body: "barbaz")
      end

      it "yields" do
        expect { |yielded|
          cdn.get(path_location, &yielded)
        }.to yield_control
      end

      it "downloads the file" do
        cdn.get(path_location) do |chunk|
          expect(chunk).to eq("barbaz")
        end
      end

      it "requests the correct url" do
        cdn.get(path_location) {}
        expect(@stub).to have_been_requested
      end
    end

    context "when CloudFront Signer is configured" do
      before { AWS::CF::Signer.stub(:is_configured?).and_return(true) }

      it "returns a signed URI using the CDN" do
        AWS::CF::Signer.should_receive(:sign_url).with("#{cdn_host}/#{path_location}").and_return("http://signed_url")
        stub = stub_request(:get, "signed_url").to_return(body: "foobar")

        cdn.get(path_location) {}

        expect(stub).to have_been_requested
      end
    end
  end
end