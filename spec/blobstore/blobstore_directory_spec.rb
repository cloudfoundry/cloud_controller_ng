require "spec_helper"

describe BlobstoreDirectory do
  let(:directory_key) { "a-directory-key" }

  let(:directories) do
    double("Fog::Storage::AWS::Directories", directories: [])
  end

  let(:connection) do
    double("Fog::Storage", directories: directories)
  end

  subject(:blobstore_directory) do
    BlobstoreDirectory.new(connection, directory_key)
  end

  describe "#exists?" do
    it "doesn't get a full listing of the contents of the directory" do
      expect(directories).to receive(:get).with(directory_key, max_keys: 0).and_return(true)
      expect(blobstore_directory).to be_exists
    end
  end

  describe "#create" do
    it "creates a private directory with the specified key" do
      expect(directories).to receive(:create).with(key: directory_key, public: false)
      blobstore_directory.create
    end
  end
end
