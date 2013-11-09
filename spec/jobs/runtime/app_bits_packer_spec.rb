require "spec_helper"

describe AppBitsPackage do
  let(:fingerprints_in_app_cache) do
    path = File.join(local_tmp_dir, "content")
    sha = "some_fake_sha"
    File.open(path, "w" ) { |f| f.write "content"  }
    global_app_bits_cache.cp_to_blobstore(path, sha)

    FingerprintsCollection.new([{"fn" => "path/to/content.txt", "size" => 123, "sha1" => sha}])
  end

  let(:compressed_path) { File.expand_path("../../../fixtures/good.zip", __FILE__) }
  let(:app) { VCAP::CloudController::AppFactory.make }
  let(:blobstore_dir) { Dir.mktmpdir }
  let(:local_tmp_dir) { Dir.mktmpdir }
  let(:global_app_bits_cache) { Blobstore.new({ provider: "Local", local_root: blobstore_dir }, "global_app_bits_cache") }
  let(:package_blobstore) { Blobstore.new({provider: "Local", local_root: blobstore_dir}, "package") }
  let(:packer) { AppBitsPackage.new(package_blobstore, global_app_bits_cache, max_droplet_size, local_tmp_dir) }
  let(:max_droplet_size) { 1_073_741_824 }

  around do |example|
    begin
      Fog.unmock!
      example.call
    ensure
      Fog.mock!
      FileUtils.remove_entry_secure local_tmp_dir
      FileUtils.remove_entry_secure blobstore_dir
    end
  end

  before do
    FileUtils.stub(:rm_f).with(compressed_path)
  end

  describe "#create" do
    subject(:create) { packer.create(app, compressed_path, fingerprints_in_app_cache) }

    it "uploads the new app bits to the app bit cache" do
      create
      sha_of_bye_file_in_good_zip = "ee9e51458f4642f48efe956962058245ee7127b1"
      expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be_true
    end

    it "uploads the new app bits to the package blob store" do
      create
      package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, "package.zip"))
      expect(`unzip -l #{local_tmp_dir}/package.zip`).to include("bye")
    end

    it "uploads the old app bits already in the app bits cache to the package blob store" do
      create
      package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, "package.zip"))
      expect(`unzip -l #{local_tmp_dir}/package.zip`).to include("path/to/content.txt")
    end

    it "uploads the package zip to the package blob store" do
      create
      expect(package_blobstore.exists?(app.guid)).to be_true
    end

    it "sets the package sha to the app" do
      expect {
        create
      }.to change {
        app.refresh.package_hash
      }
    end

    it "removes the compressed path afterwards" do
      FileUtils.should_receive(:rm_f).with(compressed_path)
      create
    end

    context "when there is no package uploaded" do
      let(:compressed_path) { nil }

      it "doesn't try to remove the file" do
        FileUtils.should_not_receive(:rm_f)
        create
      end
    end

    context "when the app bits are too large" do
      let(:max_droplet_size) { 10 }

      it "raises an exception" do
        expect {
          create
        }.to raise_exception VCAP::Errors::AppPackageInvalid, /package.+larger/i
      end

      it "removes the compressed path afterwards" do
        FileUtils.should_receive(:rm_f).with(compressed_path)
        expect { create }.to raise_exception
      end
    end

    context "when the max droplet size is not configured" do
      let(:max_droplet_size) { nil }

      it "always accepts any droplet size" do
        fingerprints_in_app_cache = FingerprintsCollection.new(
          [{"fn" => "file.txt", "size" => (2048 * 1024 * 1024) + 1, "sha1" => 'a_sha'}]
        )
        packer.create(app, compressed_path, fingerprints_in_app_cache)
      end
    end
  end
end
