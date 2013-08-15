require "spec_helper"
require "workers/runtime/app_package_worker"


describe AppPackageWorker do
  let(:worker) { AppPackageWorker.new }

  #describe "#start" do
  #  let(:valid_resource) do
  #    file = Tempfile.new("mytemp")
  #    file.write("A" * 1024)
  #    file.close
  #
  #    VCAP::CloudController::ResourcePool.instance.add_path(file.path)
  #    file_sha1 = Digest::SHA1.file(file.path).hexdigest
  #
  #    [{"fn" => "file/path", "sha1" => file_sha1, "size" => 2048}]
  #  end
  #
  #  let(:app_guid) {}
  #  let(:resources_json) {}
  #  let(:uploaded_file_path) {}
  #
  #  subject(:perform) do
  #    AppPackageWorker.new.perform(app_guid, app_bits_path, app_bits_sha1, app_bits_size)
  #  end
  #
  #  it "should save the sha1"
  #end

  describe "#upload_missing_files_to_blobstore" do
    let(:dir_of_missing_files) { mock(:fake_dir) }
    subject(:upload) { worker.upload_missing_files_to_blobstore(dir_of_missing_files) }

    it "fog uploads our files" do
      worker.resource_pool.should_receive(:add_path).with(dir_of_missing_files)
      upload
    end

    context "when an error occurs" do
      before { worker.resource_pool.should_receive(:add_path).and_raise(Fog::Errors::Error) }

      it "does something which we ask the PM on" do
        expect { upload }.to raise_error(AppPackageWorker::WrappedFogException, /Upload Missing/)
      end
    end
  end

  describe "#download_known_files_from_blobstore" do
    let(:fingerprints_already_in_blobstore) { [{ "fn" => "file.txt", "sha1" => "abc", "size" => 5 }] }
    before { worker.resource_pool.stub(:copy) }
    subject(:download) { worker.download_known_files_from_blobstore(fingerprints_already_in_blobstore) }

    context "for a top level file" do
      it "places the file in the root folder" do
        worker.resource_pool.should_receive(:copy).with(fingerprints_already_in_blobstore.first, "file.txt")
        download
      end
    end

    context "for a nested level file" do
      let(:fingerprints_already_in_blobstore) { [{ "fn" => "path/to/file.txt", "sha1" => "abc", "size" => 5 }] }

      it "creates the correct directories and places the file in it" do
        worker.resource_pool.should_receive(:copy).with(fingerprints_already_in_blobstore.first, "path/to/file.txt")
        download
      end
    end

    context "when the file path is relative" do
      let(:fingerprints_already_in_blobstore) { [{ "fn" => "path/../file.txt", "sha1" => "abc", "size" => 5 }] }

      it "should expand the path to place the file in the correct location"
    end

    context "when the path is outside the app dir" do
      let(:fingerprints_already_in_blobstore) { [{ "fn" => "../file.txt", "sha1" => "abc", "size" => 5 }] }

      it "should throw an error"
    end

    context "when there are multiple files" do
      let(:fingerprints_already_in_blobstore) do
        [
          { "fn" => "file1.txt", "sha1" => "abc", "size" => 5 },
          { "fn" => "file2.txt", "sha1" => "def", "size" => 6 }
        ]
      end

      it "places all the files in the correct places"
    end

    context "when the file is not found" do
      before { VCAP::CloudController::ResourcePool.instance.stub(:copy).and_raise(Fog::Errors::Error) }
    end
  end

  describe "#package_droplet" do

  end

  describe "#check_droplet_size" do

  end

  describe "#upload_droplet_to_blobstore" do

  end
end
