require 'spec_helper'
require 'cloud_controller/packager/local_bits_packer'

module CloudController::Packager
  RSpec.describe LocalBitsPacker do
    subject(:packer) { described_class.new }

    let(:uploaded_files_path) { File.expand_path('../../../../fixtures/good.zip', File.dirname(__FILE__)) }
    let(:blobstore_dir) { Dir.mktmpdir }
    let(:local_tmp_dir) { Dir.mktmpdir }
    let(:global_app_bits_cache) do
      CloudController::Blobstore::FogClient.new(
        connection_config: { provider: 'Local', local_root: blobstore_dir },
        directory_key:     'global_app_bits_cache',
        min_size:          4,
        max_size:          8
      )
    end
    let(:package_blobstore) do
      CloudController::Blobstore::FogClient.new(
        connection_config: { provider: 'Local', local_root: blobstore_dir },
        directory_key:     'package'
      )
    end

    before do
      allow(packer).to receive(:tmp_dir).and_return(local_tmp_dir)
      allow(packer).to receive(:package_blobstore).and_return(package_blobstore)
      allow(packer).to receive(:global_app_bits_cache).and_return(global_app_bits_cache)
      allow(packer).to receive(:max_package_size).and_return(max_package_size)

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

      it 'returns the sha of the uploaded package' do
        allow_any_instance_of(Digester).to receive(:digest_path).and_return('expected-sha')
        result_sha = packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        expect(result_sha).to eq('expected-sha')
      end

      context 'when the zip file uploaded is invalid' do
        let(:uploaded_files_path) { File.expand_path('../../../fixtures/bad.zip', File.dirname(__FILE__)) }

        it 'raises an informative error' do
          expect { packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints) }.to raise_error(CloudController::Errors::ApiError, /invalid/)
        end
      end

      context 'when the app bits are too large' do
        let(:max_package_size) { 10 }

        it 'raises an exception' do
          expect {
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          }.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
        end

        context 'because the cached files make the package too large' do
          let(:max_package_size) { 10_000 }

          before do
            allow_any_instance_of(CloudController::Blobstore::FingerprintsCollection).to receive(:storage_size).and_return(10_000)
          end

          it 'raises an exception' do
            expect {
              packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            }.to raise_error(CloudController::Errors::ApiError, /may not be larger than/)
          end
        end
      end

      describe 'bit caching' do
        let(:cached_files_fingerprints) do
          path = File.join(local_tmp_dir, 'content')
          sha  = 'some_fake_sha'
          File.open(path, 'w') { |f| f.write 'content' }
          global_app_bits_cache.cp_to_blobstore(path, sha)

          [{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha }]
        end

        it 'uploads the new app bits to the app bit cache' do
          packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
          sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
          expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
        end

        context 'when one of the files exceeds the configured maximum_size' do
          it 'it is not uploaded to the cache but the others are' do
            packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
            sha_of_greetings_file_in_good_zip = '82693f9b3a4857415aeffccd535c375891d96f74'
            sha_of_bye_file_in_good_zip       = 'ee9e51458f4642f48efe956962058245ee7127b1'
            expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
            expect(global_app_bits_cache.exists?(sha_of_greetings_file_in_good_zip)).to be false
          end
        end

        context 'when one of the files is less than the configured minimum_size' do
          it 'it is not uploaded to the cache but the others are' do
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
            expect(sprintf('%o', File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100744')
          end

          context 'when specific file permissions are requested' do
            let(:cached_files_fingerprints) do
              path = File.join(local_tmp_dir, 'content')
              sha  = 'some_fake_sha'
              File.open(path, 'w') { |f| f.write 'content' }
              global_app_bits_cache.cp_to_blobstore(path, sha)

              [{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha, 'mode' => mode }]
            end

            let(:mode) { '0653' }

            it 'uploads the old app bits with the requested permissions' do
              packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)

              package_blobstore.download_from_blobstore(blobstore_key, File.join(local_tmp_dir, 'package.zip'))
              `unzip #{local_tmp_dir}/package.zip path/to/content.txt -d #{local_tmp_dir}`
              expect(sprintf('%o', File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100653')
            end

            describe 'bad file permissions' do
              context 'when the write permissions are too-restrictive' do
                let(:mode) { '344' }

                it 'errors' do
                  expect {
                    packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
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
                    packer.send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
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
