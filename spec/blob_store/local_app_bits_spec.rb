require "spec_helper"
require "cloud_controller/blob_store/local_app_bits"

describe LocalAppBits do
  let(:zip) { mock(:file, path: "/tmp/zipped.zip") }
  let(:uncompressed_path) { "/tmp/uncompressed" }
  let(:tmp_dir) { "/tmp" }

  describe ".from_compressed_bits" do
    before do
      File.stub(:exists?).and_return(true)
      SafeZipper.stub(:unzip).and_return(123)
      Dir.stub(:mktmpdir).and_yield(uncompressed_path)
      Settings.stub(:tmp_dir).and_return(tmp_dir)
    end

    it "yields a block" do
      expect { |yielded|
        LocalAppBits.from_compressed_bits(zip, &yielded)
      }.to yield_control
    end

    it "unzips the folder" do
      SafeZipper.should_receive(:unzip).with(zip.path, uncompressed_path)

      LocalAppBits.from_compressed_bits(zip) do |local_app_bits|
        expect(local_app_bits.root_path).to eq uncompressed_path
      end
    end

    it "create and delete the tmp dir where its uncompressed" do
      Dir.should_receive(:mktmpdir).with("uncompressed", tmp_dir)

      LocalAppBits.from_compressed_bits(zip) do |local_app_bits|
        expect(local_app_bits.root_path).to start_with uncompressed_path
      end
    end

    it "gets the storage_size of the uncompressed files" do
      LocalAppBits.from_compressed_bits(zip) do |local_app_bits|
        expect(local_app_bits.storage_size).to eq 123
      end
    end

    context "when the zip file is pointing to a non existent file" do
      it "does not unzip anything" do
        File.should_receive(:exists?).with(zip.path).and_return(false)
        SafeZipper.should_not_receive(:unzip)
        LocalAppBits.from_compressed_bits(zip) do |local_app_bits|
          expect(local_app_bits.storage_size).to eq 0
        end
      end
    end

    context "when the zip file does not exist" do
      let(:zip) { nil }

      it "does not unzip anything" do
        SafeZipper.should_not_receive(:unzip)
        LocalAppBits.from_compressed_bits(zip) do |local_app_bits|
          expect(local_app_bits.storage_size).to eq 0
        end
      end
    end
  end

  describe "#create_package" do
    subject(:local_app_bits) { LocalAppBits.new(uncompressed_path, 123) }

    it "should zip up the file and yield the open stream of it" do
      path = "/tmp/uncompressed/package.zip"
      SafeZipper.should_receive(:zip).with(uncompressed_path, path)
      File.should_receive(:new).with(path).and_return(mock(:file, path: path, hexdigest: "some_sha"))

      package = local_app_bits.create_package
      expect(package.path).to eq path
      expect(package.hexdigest).to eq "some_sha"
    end
  end
end