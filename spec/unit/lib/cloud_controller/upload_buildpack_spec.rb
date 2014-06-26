require "spec_helper"

module VCAP::CloudController
  describe UploadBuildpack do

    let (:buildpack_blobstore) { double(:buildpack_blobstore).as_null_object }
    let (:buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: "upload_binary_buildpack", position: 0 }) }

    let (:upload_buildpack) { UploadBuildpack.new(buildpack_blobstore) }

    let(:tmpdir) { Dir.mktmpdir }
    let(:filename) { "file.zip" }

    let(:sha_valid_zip) do
      File.new(valid_zip.path).hexdigest
    end
    let(:sha_valid_zip2) { File.new(valid_zip2.path).hexdigest }

    let(:valid_zip) do
      zip_name = File.join(tmpdir, filename)
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip2) do
      zip_name = File.join(tmpdir, filename)
      TestZip.create(zip_name, 3, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let (:staging_timeout) { TestConfig.config[:staging][:timeout_in_seconds] }

    let(:expected_sha_valid_zip) { "#{buildpack.guid}_#{sha_valid_zip}" }

    context "upload_bits" do
      before do
        allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)
        buildpack
      end

      it "updates the buildpack filename" do
        expect{
          upload_buildpack.upload_bits(buildpack, valid_zip, filename)
        }.to change {
          Buildpack.find(name: 'upload_binary_buildpack').filename
        }.from(nil).to(filename)
      end

      context "new bits (new sha)" do
        it "copies new bits to the blobstore" do
          expect(buildpack_blobstore).to receive(:cp_to_blobstore).with(valid_zip, expected_sha_valid_zip)

          expect(upload_buildpack.upload_bits(buildpack, valid_zip, filename)).to be true
        end

        it "updates the buildpack key" do
          expect{
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
          }.to change {
            Buildpack.find(name: 'upload_binary_buildpack').key
          }.from(nil).to(expected_sha_valid_zip)
        end

        it "removes the old buildpack binary when a new one is uploaded" do
          upload_buildpack.upload_bits(buildpack, valid_zip, filename)

          allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)

          upload_buildpack.upload_bits(buildpack, valid_zip2, filename)

          expect(VCAP::CloudController::BuildpackBitsDelete).to have_received(:delete_when_safe).with(expected_sha_valid_zip, staging_timeout)
        end
      end

      context "same bits (same sha)" do
        before do
          buildpack.key = expected_sha_valid_zip
          buildpack.filename = filename
        end

        context "when bits are in the blobstore" do
          before do
            allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(true)
          end

          it "returns false if both bits and filename are not changed" do
            expect(upload_buildpack.upload_bits(buildpack, valid_zip, filename)).to be false
          end

          it "does not copy the same bits to the blobstore" do
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)

            expect(buildpack_blobstore).not_to receive(:cp_to_blobstore)
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
          end

          it "does not remove the bits if the same one is provided" do
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
            allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)

            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
            expect(VCAP::CloudController::BuildpackBitsDelete).not_to have_received(:delete_when_safe)
          end

          it "does not allow upload if the buildpack is locked" do
            locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: "locked_buildpack", locked: true, position: 0 })
            expect(upload_buildpack.upload_bits(locked_buildpack, valid_zip2, filename)).to be false
          end
        end

        context "when the bit are missing from the blobstore" do
          before do
            allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(false)
          end

          it "returns true if the bits are uploaded" do
            expect(upload_buildpack.upload_bits(buildpack, valid_zip, filename)).to be true
          end

          it "does copy the bits to the blobstore" do
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)

            expect(buildpack_blobstore).to receive(:cp_to_blobstore)
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
          end

          it "does not remove the bits if the same one is provided" do
            expect(VCAP::CloudController::BuildpackBitsDelete).not_to receive(:delete_when_safe)
            upload_buildpack.upload_bits(buildpack, valid_zip, filename)
          end

          it "does not allow upload if the buildpack is locked" do
            locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: "locked_buildpack", locked: true, position: 0 })
            expect(upload_buildpack.upload_bits(locked_buildpack, valid_zip2, filename)).to be false
          end

        end
      end

      context "when the same bits are uploaded twice" do
        let (:buildpack2) { VCAP::CloudController::Buildpack.create_from_hash({ name: "buildpack2", position: 0 }) }

        it "should have different keys" do
          upload_buildpack.upload_bits(buildpack, valid_zip2, filename)
          upload_buildpack.upload_bits(buildpack2, valid_zip2, filename)
          bp1 = Buildpack.find(name: 'upload_binary_buildpack')
          bp2 = Buildpack.find(name: 'buildpack2')
          expect(bp1.key).to_not eq(bp2.key)
        end
      end
    end
  end
end
