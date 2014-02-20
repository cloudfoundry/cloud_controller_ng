require "spec_helper"

describe BlobstoreDirectory do
  let(:fog_directory) do
    double("Fog::**::Directory")
  end

  let(:directory_key) { "a-directory-key" }

  let(:directories) do
    double("Fog::**::Directories", directories: [])
  end

  let(:connection) do
    double("Fog::Storage", directories: directories)
  end

  subject(:blobstore_directory) do
    BlobstoreDirectory.new(connection, directory_key)
  end

  describe "#create" do
    it "creates a private directory with the specified key and retrieves it" do
      expect(directories).to receive(:create).with(key: directory_key, public: false).and_return(fog_directory)
      expect(blobstore_directory.create).to eq(fog_directory)
    end
  end

  describe "#get" do
    it "retrieves the directory" do
      expect(directories).to receive(:get).with(directory_key).and_return(fog_directory)
      expect(blobstore_directory.get).to eq(fog_directory)
    end
  end
end
