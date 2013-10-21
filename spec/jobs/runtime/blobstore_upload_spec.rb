require "spec_helper"

describe BlobstoreUpload do
  let(:local_file) do
    Tempfile.new("tmpfile")
  end

  let(:blobstore_key) do
    "key"
  end

  let(:blobstore_name) do
    :droplet_blobstore
  end

  subject do
    described_class.new(local_file.path, blobstore_key, blobstore_name)
  end

  let!(:blobstore) do
    CloudController::DependencyLocator.instance.droplet_blobstore
  end

  before do
    CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
  end

  it "uploads the file to the blostore" do
    expect do
      subject.perform
    end.to change{ blobstore.exists?(blobstore_key) }.to(true)
  end

  it "cleans up the file at the end" do
    subject.perform
    expect(File.exists?(local_file.path)).to be_false
  end
end

