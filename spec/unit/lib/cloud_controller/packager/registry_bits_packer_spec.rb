require 'spec_helper'
require 'cloud_controller/packager/registry_bits_packer'

module CloudController::Packager
  RSpec.describe RegistryBitsPacker do
    subject(:packer) { RegistryBitsPacker.new }

    let(:uploaded_files_path) { File.join(local_tmp_dir, 'good.zip') }
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:blobstore_dir) { Dir.mktmpdir }
    let(:local_tmp_dir) { Dir.mktmpdir }
    let(:registry_buddy_client) { instance_double(RegistryBuddy::Client) }
    let(:package_guid) { 'im-a-package-guid' }
    let(:registry) { 'hub.example.com/user' }
    let(:min_size) { 4 }
    let(:max_size) { 8 }
    let(:global_app_bits_cache) do
      CloudController::Blobstore::FogClient.new(
        connection_config: { provider: 'Local', local_root: blobstore_dir },
        directory_key:     'global_app_bits_cache',
        min_size:          min_size,
        max_size:          max_size
      )
    end

    let(:fingerprints) do
      path = File.join(local_tmp_dir, 'content')
      sha  = 'some_fake_sha'
      File.open(path, 'w') { |f| f.write 'content' }
      global_app_bits_cache.cp_to_blobstore(path, sha)

      [{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha }]
    end

    before do
      TestConfig.override(directories: { tmpdir: local_tmp_dir }, packages: { image_registry: { base_path: registry } })

      allow(CloudController::DependencyLocator.instance).to receive(:global_app_bits_cache).and_return(global_app_bits_cache)
      allow(packer).to receive(:max_package_size).and_return(max_package_size)

      allow(RegistryBuddy::Client).to receive(:new).and_return(registry_buddy_client)
      allow(registry_buddy_client).to receive(:post_package).and_return(
        'hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' }
      )

      FileUtils.cp(input_zip, local_tmp_dir)
      FileUtils.mkdir(File.join(local_tmp_dir, '/packages/'))
      FileUtils.chmod(0400, uploaded_files_path) rescue nil

      Fog.unmock!
    end

    after do
      Fog.mock!
      FileUtils.remove_entry_secure local_tmp_dir
      FileUtils.remove_entry_secure blobstore_dir
    end

    describe '#send_package_to_blobstore' do
      let(:max_package_size) { nil }
      let(:package_guid) { 'package-guid' }
      let(:cached_files_fingerprints) { [] }

      it 'uploads to the registry and returns the uploaded file hash' do
        expect(registry_buddy_client).to receive(:post_package).
          with(package_guid, %r{#{local_tmp_dir}\/packages\/registry_bits_packer}, registry).
          and_return('hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' })

        result_hash = packer.send_package_to_blobstore(package_guid, uploaded_files_path, [])
        expect(result_hash).to eq({ sha1: nil, sha256: 'sha-2-5-6-hex' })
      end

      context 'when uploading the package to the bits service fails' do
        let(:expected_exception) { StandardError.new('some error') }

        it 'raises the exception' do
          allow(registry_buddy_client).to receive(:post_package).and_raise(expected_exception)
          expect {
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, [])
          }.to raise_error(expected_exception)
        end
      end

      context 'when the package zip file path is nil' do
        let(:uploaded_files_path) { nil }

        context 'and there are NO cached files' do
          let(:cached_files_fingerprints) { [] }

          it 'raises an error' do
            expect {
              packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
            }.to raise_error(CloudController::Errors::ApiError, /Invalid zip/)
          end
        end

        context 'and there are cached files' do
          let(:cached_files_fingerprints) { fingerprints }

          it 'packs a zip with the cached files' do
            expect(registry_buddy_client).to receive(:post_package).
              with(package_guid, %r{#{local_tmp_dir}\/packages\/registry_bits_packer}, registry).
              and_return('hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' })

            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
          end

          context 'and the combined matched resources are too large' do
            let(:max_package_size) { 1 }

            it 'raises an exception' do
              expect {
                packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
              }.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
            end
          end
        end
      end

      context 'when the package zip file is missing ' do
        let(:uploaded_files_path) { File.join(local_tmp_dir, 'file_that_does_not_exist.zip') }

        context 'and there are NO cached files' do
          let(:cached_files_fingerprints) { [] }

          it 'raises an error' do
            expect {
              packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
            }.to raise_error(CloudController::Errors::ApiError, /Invalid zip/)
          end
        end

        context 'and there are cached files' do
          let(:cached_files_fingerprints) { fingerprints }

          it 'packs a zip with the cached files' do
            expect(registry_buddy_client).to receive(:post_package).
              with(package_guid, %r{#{local_tmp_dir}\/packages\/registry_bits_packer}, registry).
              and_return('hash' => { 'algorithm' => 'sha256', 'hex' => 'sha-2-5-6-hex' })
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
          end
        end
      end

      context 'when the zip file is invalid' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'bad.zip') }
        let(:uploaded_files_path) { File.join(local_tmp_dir, 'bad.zip') }

        it 'raises an informative error' do
          expect {
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
          }.to raise_error(CloudController::Errors::ApiError, /invalid/)
        end
      end

      context 'when the app bits are too large' do
        let(:max_package_size) { 1 }

        it 'raises an exception' do
          expect {
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
          }.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
        end

        it 'does not populate the cache' do
          packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints) rescue nil
          sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
          expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be false
        end
      end

      describe 'bit caching' do
        let(:cached_files_fingerprints) { fingerprints }

        it 'uploads the new app bits to the app bit cache' do
          packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
          sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
          expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
        end

        it 'initializes the fingerprints collection to be scoped to the temporary working directory' do
          expect(CloudController::Blobstore::FingerprintsCollection).to receive(:new).with(fingerprints, %r{#{local_tmp_dir}\/packages\/registry_bits_packer}).and_return([])
          packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
        end

        context 'when there is an unreadable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'unreadable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'unreadable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect {
              packer.send_package_to_blobstore(package_guid, input_zip_file_path, [])
            }.to_not change {
              Dir.entries(local_tmp_dir)
            }
          end
        end

        context 'when there is an undeletable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'undeletable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'undeletable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect {
              packer.send_package_to_blobstore(package_guid, input_zip_file_path, [])
            }.to_not change {
              Dir.entries(local_tmp_dir)
            }
          end
        end

        context 'when there is an untraversable directory in the zip' do
          let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'untraversable_dir.zip') }
          let(:input_zip_file_path) { File.join(local_tmp_dir, 'untraversable_dir.zip') }

          it 'is able to clean up all files regardless of their permissions in the zip' do
            expect {
              packer.send_package_to_blobstore(package_guid, input_zip_file_path, [])
            }.to_not change {
              Dir.entries(local_tmp_dir)
            }
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
            FileUtils.chmod(0600, uploaded_files_path)
            `zip -r --symlinks "#{uploaded_files_path}" "#{symlink_path}"`

            packer.send_package_to_blobstore(package_guid, uploaded_files_path, [])
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
          it 'it is not uploaded to the cache but the others are' do
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
            sha_of_greetings_file_in_good_zip = '82693f9b3a4857415aeffccd535c375891d96f74'
            sha_of_bye_file_in_good_zip       = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
            expect(global_app_bits_cache.exists?(sha_of_greetings_file_in_good_zip)).to be false
          end
        end

        context 'when one of the files is less than the configured minimum_size' do
          it 'it is not uploaded to the cache but the others are' do
            packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
            sha_of_hi_file_in_good_zip  = '55ca6286e3e4f4fba5d0448333fa99fc5a404a73'
            sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
            expect(global_app_bits_cache.exists?(sha_of_hi_file_in_good_zip)).to be false
          end
        end

        describe 'cached/old app bits' do
          context 'when specific file permissions are requested' do
            let(:cached_files_fingerprints) do
              fingerprints.tap { |prints| prints[0]['mode'] = mode }
            end

            let(:mode) { '0653' }

            describe 'bad file permissions' do
              context 'when the write permissions are too-restrictive' do
                let(:mode) { '344' }

                it 'errors' do
                  expect {
                    packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
                  }.to raise_error do |error|
                    expect(error.name).to eq 'AppResourcesFileModeInvalid'
                    expect(error.response_code).to eq 400
                  end
                end
              end

              context 'when the permissions are nonsense' do
                let(:mode) { 'banana' }

                it 'errors' do
                  expect {
                    packer.send_package_to_blobstore(package_guid, uploaded_files_path, cached_files_fingerprints)
                  }.to raise_error do |error|
                    expect(error.name).to eq 'AppResourcesFileModeInvalid'
                    expect(error.response_code).to eq 400
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
