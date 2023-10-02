require 'spec_helper'
require 'cloud_controller/packager/local_bits_packer'

module CloudController::Packager
  RSpec.describe LocalBitsPacker do
    subject(:packer) { LocalBitsPacker.new }

    let(:uploaded_files_path) { File.join(local_tmp_dir, 'good.zip') }
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:blobstore_dir) { Dir.mktmpdir }
    let(:local_tmp_dir) { Dir.mktmpdir }
    let(:min_size) { 4 }
    let(:max_size) { 8 }
    let(:global_app_bits_cache) do
      CloudController::Blobstore::FogClient.new(
        connection_config: { provider: 'Local', local_root: blobstore_dir },
        directory_key: 'global_app_bits_cache',
        min_size: min_size,
        max_size: max_size
      )
    end
    let(:package_blobstore) do
      CloudController::Blobstore::FogClient.new(
        connection_config: { provider: 'Local', local_root: blobstore_dir },
        directory_key: 'package'
      )
    end

    let(:fingerprints) do
      path = File.join(local_tmp_dir, 'content')
      sha  = 'some_fake_sha'
      File.write(path, 'content')
      global_app_bits_cache.cp_to_blobstore(path, sha)

      [{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha }]
    end

    before do
      TestConfig.override(directories: { tmpdir: local_tmp_dir })

      allow(CloudController::DependencyLocator.instance).to receive_messages(global_app_bits_cache:, package_blobstore:)
      allow(packer).to receive(:max_package_size).and_return(max_package_size)

      FileUtils.cp(input_zip, local_tmp_dir)
      begin
        FileUtils.chmod(0o400, uploaded_files_path)
      rescue StandardError
        nil
      end

      Fog.unmock!
    end

    after do
      Fog.mock!
      FileUtils.remove_entry_secure local_tmp_dir
      FileUtils.remove_entry_secure blobstore_dir
    end

    describe '#send_package_to_blobstore' do
      let(:max_package_size) { nil }
      let(:blobstore_key) { 'a-blobstore-key' }
      let(:cached_files_fingerprints) { [] }

      it 'uploads the package zip to the package blob store' do
        packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        expect(package_blobstore.exists?(blobstore_key)).to be true
      end

      it 'returns the sha1 and sha256 of the uploaded package' do
        sha1_digester = instance_double(Digester, digest_path: 'expected-sha1')
        sha256_digester = instance_double(Digester, digest_path: 'expected-sha256')

        allow(Digester).to receive(:new).with(no_args).and_return(sha1_digester)
        allow(Digester).to receive(:new).with(algorithm: OpenSSL::Digest::SHA256).and_return(sha256_digester)

        result_sha = packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)

        expect(result_sha).to eq({
                                   sha1: 'expected-sha1',
                                   sha256: 'expected-sha256'
                                 })
      end

      context 'when the package zip file path is nil' do
        let(:uploaded_files_path) { nil }

        context 'and there are NO cached files' do
          let(:cached_files_fingerprints) { [] }

          it 'raises an error' do
            expect do
              packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            end.to raise_error(CloudController::Errors::ApiError, /Invalid zip/)
          end
        end

        context 'and there are cached files' do
          let(:cached_files_fingerprints) { fingerprints }

          it 'packs a zip with the cached files' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            expect(package_blobstore.exists?(blobstore_key)).to be true
          end

          context 'and the combined matched resources are too large' do
            let(:max_package_size) { 1 }

            it 'raises an exception' do
              expect do
                packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
              end.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
            end
          end
        end
      end

      context 'when the package zip file is missing' do
        let(:uploaded_files_path) { File.join(local_tmp_dir, 'file_that_does_not_exist.zip') }

        context 'and there are NO cached files' do
          let(:cached_files_fingerprints) { [] }

          it 'raises an error' do
            expect do
              packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            end.to raise_error(CloudController::Errors::ApiError, /Invalid zip/)
          end
        end

        context 'and there are cached files' do
          let(:cached_files_fingerprints) { fingerprints }

          it 'packs a zip with the cached files' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            expect(package_blobstore.exists?(blobstore_key)).to be true
          end
        end
      end

      context 'when the zip file is invalid' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'bad.zip') }
        let(:uploaded_files_path) { File.join(local_tmp_dir, 'bad.zip') }

        it 'raises an informative error' do
          expect do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          end.to raise_error(CloudController::Errors::ApiError, /invalid/)
        end
      end

      context 'when the app bits are too large' do
        let(:max_package_size) { 1 }

        it 'raises an exception' do
          expect do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          end.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
        end

        it 'does not populate the cache' do
          begin
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          rescue StandardError
            nil
          end
          sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
          expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be false
        end
      end

      describe 'bit caching' do
        let(:cached_files_fingerprints) { fingerprints }

        it 'uploads the new app bits to the app bit cache' do
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
          expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
        end

        it 'initializes the fingerprints collection to be scoped to the temporary working directory' do
          expect(CloudController::Blobstore::FingerprintsCollection).to receive(:new).with(fingerprints, %r{#{local_tmp_dir}/local_bits_packer}).and_return([])
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        end

        context 'when the resource_matching feature flag is disabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'resource_matching', enabled: false)
          end

          it 'does not upload any app bits to the app bit cache' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be false
          end
        end

        context 'when there is an unreadable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'unreadable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'unreadable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect do
              packer.send_package_to_blobstore(blobstore_key, input_zip_file_path, [])
            end.not_to(change do
              Dir.entries(local_tmp_dir)
            end)
          end
        end

        context 'when there is an undeletable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'undeletable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'undeletable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect do
              packer.send_package_to_blobstore(blobstore_key, input_zip_file_path, [])
            end.not_to(change do
              Dir.entries(local_tmp_dir)
            end)
          end
        end

        context 'when there is an untraversable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'untraversable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'untraversable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect do
              packer.send_package_to_blobstore(blobstore_key, input_zip_file_path, [])
            end.not_to(change do
              Dir.entries(local_tmp_dir)
            end)
          end
        end

        context 'when some of the files are symlinks' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'express-app.zip') }
          let(:uploaded_files_path) { File.join(local_tmp_dir, 'express-app.zip') }
          let(:min_size) { 0 }
          let(:max_size) { 1_000_000 }

          it 'they are not uploaded to the cache but the real files are' do
            tempfile = Tempfile.new('external_file.txt')
            File.open(tempfile.path, 'w') { |fd| fd.puts 'text goes here' }

            symlink_path = File.join(local_tmp_dir, 'link-to-temp.txt')
            FileUtils.ln_s(tempfile.path, symlink_path)

            # Make the zipfile writable so we can dynamically insert the symlink
            FileUtils.chmod(0o600, uploaded_files_path)
            `zip -r --symlinks "#{uploaded_files_path}" "#{symlink_path}"`

            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, [])
            expect(global_app_bits_cache.files_for('').size).to be 2

            sha_of_cli_js = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
            sha_of_target1_txt = 'f572d396fae9206628714fb2ce00f72e94f2258f'
            absolute_link_sha1 = Digester.new.digest_path(tempfile.path)
            expect(global_app_bits_cache.exists?(sha_of_cli_js)).to be true
            expect(global_app_bits_cache.exists?(sha_of_target1_txt)).to be true
            expect(global_app_bits_cache.exists?(absolute_link_sha1)).to be false
          end
        end

        context 'when one of the files exceeds the configured maximum_size' do
          it 'is not uploaded to the cache but the others are' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            sha_of_greetings_file_in_good_zip = '82693f9b3a4857415aeffccd535c375891d96f74'
            sha_of_bye_file_in_good_zip       = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
            expect(global_app_bits_cache.exists?(sha_of_greetings_file_in_good_zip)).to be false
          end
        end

        context 'when one of the files is less than the configured minimum_size' do
          it 'is not uploaded to the cache but the others are' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            sha_of_hi_file_in_good_zip  = '55ca6286e3e4f4fba5d0448333fa99fc5a404a73'
            sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
            expect(global_app_bits_cache.exists?(sha_of_hi_file_in_good_zip)).to be false
          end
        end

        describe 'cached/old app bits' do
          it 'uploads the old app bits already in the app bits cache to the package blob store' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)

            package_blobstore.download_from_blobstore(blobstore_key, File.join(local_tmp_dir, 'package.zip'))
            expect(`unzip -l #{local_tmp_dir}/package.zip`).to include('path/to/content.txt')
          end

          it 'defaults the files to 744 permissions' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)

            package_blobstore.download_from_blobstore(blobstore_key, File.join(local_tmp_dir, 'package.zip'))
            `unzip #{local_tmp_dir}/package.zip path/to/content.txt -d #{local_tmp_dir}`
            expect(sprintf('%<mode>o', mode: File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100744')
          end

          context 'when specific file permissions are requested' do
            let(:cached_files_fingerprints) do
              fingerprints.tap { |prints| prints[0]['mode'] = mode }
            end

            let(:mode) { '0653' }

            it 'uploads the old app bits with the requested permissions' do
              packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)

              package_blobstore.download_from_blobstore(blobstore_key, File.join(local_tmp_dir, 'package.zip'))
              `unzip #{local_tmp_dir}/package.zip path/to/content.txt -d #{local_tmp_dir}`
              expect(sprintf('%<mode>o', mode: File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100653')
            end
          end
        end
      end
    end
  end
end
