require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UploadBuildpack do
    let(:buildpack_blobstore) { double(:buildpack_blobstore).as_null_object }
    let!(:buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', position: 0 }) }

    let(:upload_buildpack) { UploadBuildpack.new(buildpack_blobstore) }

    let(:tmpdir) { Dir.mktmpdir }
    let(:filename) { 'file.zip' }

    let(:sha_valid_zip) { Digester.new.digest_file(valid_zip) }
    let(:sha_valid_zip2) { Digester.new.digest_file(valid_zip2) }

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

    let(:staging_timeout) { TestConfig.config[:staging][:timeout_in_seconds] }

    let(:expected_sha_valid_zip) { "#{buildpack.guid}_#{sha_valid_zip}" }

    context 'upload_buildpack' do
      before do
        allow(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)
      end

      context 'and the upload to the blobstore succeeds' do
        it 'updates the buildpack filename' do
          expect {
            upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          }.to change {
            Buildpack.find(name: 'upload_binary_buildpack').filename
          }.from(nil).to(filename)
        end

        context 'new bits (new sha)' do
          it 'copies new bits to the blobstore and updates the key' do
            expect(buildpack_blobstore).to receive(:cp_to_blobstore).with(valid_zip, expected_sha_valid_zip)
            expect {
              upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
            }.to change {
              Buildpack.find(name: 'upload_binary_buildpack').key
            }.from(nil).to(expected_sha_valid_zip)
          end

          it 'does not attempt to delete the old buildpack blob when it does not exist' do
            expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
            upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          end

          context 'when there is an old buildpack in the blobstore' do
            before { buildpack.update(key: 'existing_key') }

            it 'removes the old buildpack binary when a new one is uploaded' do
              allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)
              upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
              expect(VCAP::CloudController::BuildpackBitsDelete).to have_received(:delete_when_safe).with('existing_key', staging_timeout)
            end
          end

          context 'when two upload_buildpack calls are running at the same time' do
            it 'does not delete the buildpack' do
              expect(buildpack_blobstore).to receive(:cp_to_blobstore) do
                Buildpack.find(name: 'upload_binary_buildpack').update(key: expected_sha_valid_zip)
              end

              expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be true
            end
          end
        end

        context 'same bits (same sha)' do
          before do
            buildpack.update(key: expected_sha_valid_zip, filename: filename)
          end

          context 'when bits provided are already in the blobstore' do
            before do
              allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(true)
            end

            it 'does not copy bits to the blobstore if nothing has changed' do
              expect(buildpack_blobstore).not_to receive(:cp_to_blobstore)
              expect(VCAP::CloudController::BuildpackBitsDelete).to_not receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be false
            end
          end

          context 'when the bit are missing from the blobstore' do
            before do
              allow(buildpack_blobstore).to receive(:exists?).with(expected_sha_valid_zip).and_return(false)
            end

            it 'returns true if the bits are uploaded and does not remove the bits' do
              expect(buildpack_blobstore).to receive(:cp_to_blobstore)
              expect(VCAP::CloudController::BuildpackBitsDelete).not_to receive(:delete_when_safe)
              expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be true
            end
          end
        end

        context 'when the same bits are uploaded twice' do
          let(:buildpack2) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'buildpack2', position: 0 }) }

          it 'should have different keys' do
            upload_buildpack.upload_buildpack(buildpack, valid_zip2, filename)
            upload_buildpack.upload_buildpack(buildpack2, valid_zip2, filename)
            bp1 = Buildpack.find(name: 'upload_binary_buildpack')
            bp2 = Buildpack.find(name: 'buildpack2')
            expect(bp1.key).to_not eq(bp2.key)
          end
        end
      end

      context 'and the upload to the blobstore fails' do
        let(:previous_key) { 'previous_key' }
        let(:previous_filename) { 'previous_filename' }

        before do
          allow(buildpack_blobstore).to receive(:cp_to_blobstore).and_raise
          buildpack.update(key: previous_key, filename: previous_filename)
        end

        it 'should not update the key and filename on the existing buildpack' do
          expect { upload_buildpack.upload_buildpack(buildpack, valid_zip, filename) }.to raise_error(RuntimeError)
          bp = Buildpack.find(name: buildpack.name)
          expect(bp).to_not be_nil
          expect(bp.key).to eq(previous_key)
          expect(bp.filename).to eq(previous_filename)
        end
      end

      context 'when updating the buildpack fails' do
        before do
          allow(buildpack_blobstore).to receive(:cp_to_blobstore) do
            buildpack.delete
          end
        end

        it 'deletes the uploaded blob from the blobstore' do
          allow(VCAP::CloudController::BuildpackBitsDelete).to receive(:delete_when_safe)

          upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)
          expect(BuildpackBitsDelete).to have_received(:delete_when_safe).with(expected_sha_valid_zip, 0)
        end
      end

      context 'when the buildpack is locked' do
        before { buildpack.update(locked: true) }

        it 'does nothing' do
          expect(buildpack_blobstore).to_not receive(:cp_to_blobstore)
          expect(upload_buildpack.upload_buildpack(buildpack, valid_zip, filename)).to be false
        end
      end
    end
  end
end
