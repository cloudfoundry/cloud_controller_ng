require "spec_helper"
require "cloud_controller/blobstore/fingerprints_collection"

module CloudController
  module Blobstore
    describe FingerprintsCollection do
      let(:fingerprints) do
        [
          {"fn" => "path/to/file.txt", "size" => 123, "sha1" => "abc"},
          {"fn" => "path/to/file2.txt", "size" => 321, "sha1" => "def"},
          {"fn" => "path/to/file3.txt", "size" => 112, "sha1" => "fad"}
        ]
      end

      let(:collection) {FingerprintsCollection.new(fingerprints)}

      describe ".new" do
        it "validates that the input is a array of hashes" do
          expect {
            FingerprintsCollection.new("")
          }.to raise_error VCAP::Errors::ApiError, /invalid/
        end
      end

      describe "#each" do
        it "returns each sha one by one" do
          expect { |yielded|
            collection.each(&yielded)
          }.to yield_successive_args(["path/to/file.txt", "abc"], ["path/to/file2.txt", "def"], ["path/to/file3.txt", "fad"])
        end
      end

      describe "#storage_size" do
        it "sums the sizes" do
          expect(collection.storage_size).to eq 123 + 321 + 112
        end
      end
    end
  end
end
