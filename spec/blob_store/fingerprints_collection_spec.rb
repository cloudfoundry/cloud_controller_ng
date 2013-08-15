require "spec_helper"
require "cloud_controller/blob_store/fingerprints_collection"

describe FingerprintsCollection do

  let(:fingerprints) do
    [
      {"fn" => "path/to/file.txt", "size" => 123, "sha1" => "abc"},
      {"fn" => "path/to/file2.txt", "size" => 321, "sha1" => "def"},
      {"fn" => "path/to/file3.txt", "size" => 112, "sha1" => "fad"}
    ]
  end

  describe "#each_sha" do
    let(:collection) {FingerprintsCollection.new(fingerprints)}

    it "returns each sha one by one" do
      expect { |yielded|
        collection.each_sha(&yielded)
      }.to yield_successive_args("abc", "def", "fad")
    end
  end
end
