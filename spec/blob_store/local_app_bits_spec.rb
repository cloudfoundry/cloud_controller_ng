require "spec_helper"
require "cloud_controller/blob_store/local_app_bits"

describe LocalAppBits do
  let(:zip_path) { "/tmp/zipped.zip" }
  let(:unzipped_path) { "/tmp/unzipped" }
  let(:tmp_dir) { "/tmp" }

  describe ".from_zip_of_new_files" do
    before do
      SafeZipper.stub(:unzip).and_return(123)
      Dir.stub(:mktmpdir).and_yield(unzipped_path)
      Settings.stub(:tmp_dir).and_return(tmp_dir)
    end

    it "yields a block" do
      expect { |yielded|
        LocalAppBits.from_zip_of_new_files(zip_path, &yielded)
      }.to yield_control
    end

    it "unzips the folder" do
      SafeZipper.should_receive(:unzip).with(zip_path, unzipped_path)

      LocalAppBits.from_zip_of_new_files(zip_path) do |local_app_bits|
        expect(local_app_bits.root_path).to eq unzipped_path
      end
    end

    it "create and delete the tmp dir where its unzipped" do
      Dir.should_receive(:mktmpdir).with("unzipped", tmp_dir)

      LocalAppBits.from_zip_of_new_files(zip_path) do |local_app_bits|
        expect(local_app_bits.root_path).to start_with unzipped_path
      end
    end

    it "gets the storage_size of the unzipped files" do
      LocalAppBits.from_zip_of_new_files(zip_path) do |local_app_bits|
        expect(local_app_bits.storage_size).to eq 123
      end
    end
  end

  describe "#create_package" do
    subject(:local_app_bits) { LocalAppBits.new(unzipped_path, 123) }

    it "should zip up the file and yield the open stream of it" do
      path = "/tmp/unzipped/package.zip"
      SafeZipper.should_receive(:zip).with(unzipped_path, path)

      expect(local_app_bits.create_package).to eq path
    end
  end
end