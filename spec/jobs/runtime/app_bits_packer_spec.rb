require "spec_helper"
require "jobs/runtime/app_bits_packer"

describe AppBitsPacker do
  let(:fingerprints_in_app_cache) do
    path = File.join(local_tmp_dir, "content")
    sha = "some_fake_sha"
    File.open(path, "w" ) { |f| f.write "content"  }
    app_bit_cache.cp_from_local(path, sha)

    FingerprintsCollection.new([{"fn" => "path/to/content.txt", "size" => 123, "sha1" => sha}])
  end

  let(:compressed_path) { File.expand_path("../../../fixtures/good.zip", __FILE__) }
  let(:app) { VCAP::CloudController::Models::App.make }
  let(:blob_store_dir) { Dir.mktmpdir }
  let(:local_tmp_dir) { Dir.mktmpdir }
  let(:app_bit_cache) { BlobStore.new({ provider: "Local", local_root: blob_store_dir }, "app_bit_cache") }
  let(:package_blob_store) { BlobStore.new({provider: "Local", local_root: blob_store_dir}, "package") }
  let(:packer) { AppBitsPacker.new(package_blob_store, app_bit_cache, max_droplet_size, local_tmp_dir) }
  let(:blob_store_dir) { Dir.mktmpdir }
  let(:max_droplet_size) { 1_073_741_824 }

  around do |example|
    begin
      Fog.unmock!
      example.call
    ensure
      Fog.mock!
      FileUtils.remove_entry_secure local_tmp_dir
      FileUtils.remove_entry_secure blob_store_dir
    end
  end

  describe "#perform" do
    subject(:perform) { packer.perform(app, compressed_path, fingerprints_in_app_cache) }

    it "uploads the new app bits to the app bit cache" do
      perform
      sha_of_bye_file_in_good_zip = "ee9e51458f4642f48efe956962058245ee7127b1"
      expect(app_bit_cache.exists?(sha_of_bye_file_in_good_zip)).to be_true
    end

    it "uploads the new app bits to the package blob store" do
      perform
      package_blob_store.cp_to_local(app.guid, File.join(local_tmp_dir, "package.zip"))
      expect(`unzip -l #{local_tmp_dir}/package.zip`).to include("bye")
    end

    it "uploads the old app bits already in the app bits cache to the package blob store" do
      perform
      package_blob_store.cp_to_local(app.guid, File.join(local_tmp_dir, "package.zip"))
      expect(`unzip -l #{local_tmp_dir}/package.zip`).to include("path/to/content.txt")
    end

    it "uploads the package zip to the package blob store" do
      perform
      expect(package_blob_store.exists?(app.guid)).to be_true
    end

    it "sets the package sha to the app" do
      expect {
        perform
      }.to change {
        app.refresh.package_hash
      }.from(nil).to(/.+/)
    end

    context "when the app bits are too large" do
      let(:max_droplet_size) { 10 }

      it "raises an exception" do
        expect {
          perform
        }.to raise_exception VCAP::Errors::AppPackageInvalid, /package.+larger/i
      end
    end

    context "when the max droplet size is not configured" do
      let(:max_droplet_size) { nil }

      it "always accepts any droplet size" do
        fingerprints_in_app_cache = FingerprintsCollection.new(
          [{"fn" => "file.txt", "size" => (2048 * 1024 * 1024) + 1, "sha1" => 'a_sha'}]
        )
        packer.perform(app, compressed_path, fingerprints_in_app_cache)
      end
    end
  end
end
