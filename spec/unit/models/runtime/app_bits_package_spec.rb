require 'spec_helper'

RSpec.describe AppBitsPackage do
  let(:compressed_path) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
  let(:app) { VCAP::CloudController::AppFactory.make }
  let(:package) { VCAP::CloudController::PackageModel.make }
  let(:blobstore_dir) { Dir.mktmpdir }
  let(:local_tmp_dir) { Dir.mktmpdir }

  let(:global_app_bits_cache) do
    CloudController::Blobstore::FogClient.new(connection_config: { provider: 'Local', local_root: blobstore_dir },
                                              directory_key: 'global_app_bits_cache',
                                              min_size: 4,
                                              max_size: 8)
  end

  let(:package_blobstore) do
    CloudController::Blobstore::FogClient.new(connection_config: { provider: 'Local', local_root: blobstore_dir },
                                              directory_key: 'package')
  end

  let(:packer) { AppBitsPackage.new }
  let(:max_package_size) { 1_073_741_824 }

  before do
    allow(packer).to receive(:tmp_dir).and_return(local_tmp_dir)
    allow(packer).to receive(:package_blobstore).and_return(package_blobstore)
    allow(packer).to receive(:global_app_bits_cache).and_return(global_app_bits_cache)
    allow(packer).to receive(:max_package_size).and_return(max_package_size)

    Fog.unmock!
    allow(FileUtils).to receive(:rm_f).with(compressed_path)
  end

  after do
    Fog.mock!
    FileUtils.remove_entry_secure local_tmp_dir
    FileUtils.remove_entry_secure blobstore_dir
  end

  describe '#create_package_in_blobstore' do
    let(:max_package_size) { nil }
    let(:package_guid) { package.guid }
    subject(:create) { packer.create_package_in_blobstore(package_guid, compressed_path) }

    it 'uploads the package zip to the package blob store' do
      create
      expect(package_blobstore.exists?(package_guid)).to be true
    end

    it 'sets the package sha to the package' do
      expect { create }.to change { package.refresh.package_hash }
    end

    it 'sets the state of the package' do
      expect { create }.to change { package.refresh.state }.to('READY')
    end

    it 'removes the compressed path afterwards' do
      expect(FileUtils).to receive(:rm_f).with(compressed_path)
      create
    end

    it 'expires any old packages' do
      allow(VCAP::CloudController::Config).to receive(:config) { {} }
      expect_any_instance_of(VCAP::CloudController::BitsExpiration).to receive(:expire_packages!)
      create
    end

    context 'when there is no package uploaded' do
      let(:compressed_path) { nil }

      it "doesn't try to remove the file" do
        expect(FileUtils).not_to receive(:rm_f)
        create
      end
    end

    context 'when the package no longer exists' do
      let(:package_guid) { 'abcd' }

      it 'raises an error and removes the compressed path' do
        expect(FileUtils).to receive(:rm_f).with(compressed_path)
        expect { create }.to raise_error(AppBitsPackage::PackageNotFound)
      end
    end

    context 'when the zip file uploaded is invalid' do
      let(:compressed_path) { File.expand_path('../../../fixtures/bad.zip', File.dirname(__FILE__)) }

      it 'raises an informative error' do
        (expect { create }).to raise_error(AppBitsPackage::InvalidZip)
      end
    end

    context 'when copying to the blobstore fails' do
      it 'logs the exception on the package and reraises the exception' do
        allow(package_blobstore).to receive(:cp_to_blobstore).and_raise('BOOM')
        expect { create }.to raise_error('BOOM')
        expect(package.reload.state).to eq('FAILED')
        expect(package.error).to eq('BOOM')
      end

      it 'removes the compressed path afterwards' do
        expect(FileUtils).to receive(:rm_f).with(compressed_path)
        create
      end
    end

    context 'when the app bits are too large' do
      let(:max_package_size) { 10 }

      it 'raises an exception and deletes the bits' do
        expect(FileUtils).to receive(:rm_f).with(compressed_path)
        expect {
          create
        }.to raise_error(AppBitsPackage::ZipSizeExceeded)
      end
    end
  end

  describe '#create' do
    subject(:create) { packer.create(app, compressed_path, fingerprints_in_app_cache) }

    let(:fingerprints_in_app_cache) do
      path = File.join(local_tmp_dir, 'content')
      sha = 'some_fake_sha'
      File.open(path, 'w') { |f| f.write 'content' }
      global_app_bits_cache.cp_to_blobstore(path, sha)

      CloudController::Blobstore::FingerprintsCollection.new([{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha }])
    end

    it 'uploads the new app bits to the app bit cache' do
      create
      sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
      expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
    end

    context 'when one of the files exceeds the configured maximum_size' do
      it 'it is not uploaded to the cache but the others are' do
        create
        sha_of_greetings_file_in_good_zip = '82693f9b3a4857415aeffccd535c375891d96f74'
        sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
        expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
        expect(global_app_bits_cache.exists?(sha_of_greetings_file_in_good_zip)).to be false
      end
    end

    context 'when one of the files is less than the configured minimum_size' do
      it 'it is not uploaded to the cache but the others are' do
        create
        sha_of_hi_file_in_good_zip = '55ca6286e3e4f4fba5d0448333fa99fc5a404a73'
        sha_of_bye_file_in_good_zip = 'ee9e51458f4642f48efe956962058245ee7127b1'
        expect(global_app_bits_cache.exists?(sha_of_bye_file_in_good_zip)).to be true
        expect(global_app_bits_cache.exists?(sha_of_hi_file_in_good_zip)).to be false
      end
    end

    it 'uploads the new app bits to the package blob store' do
      create

      package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, 'package.zip'))
      expect(`unzip -l #{local_tmp_dir}/package.zip`).to include('bye')
    end

    describe 'cached/old app bits' do
      it 'uploads the old app bits already in the app bits cache to the package blob store' do
        create

        package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, 'package.zip'))
        expect(`unzip -l #{local_tmp_dir}/package.zip`).to include('path/to/content.txt')
      end

      it 'defaults the files to 744 permissions' do
        create

        package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, 'package.zip'))
        `unzip #{local_tmp_dir}/package.zip path/to/content.txt -d #{local_tmp_dir}`
        expect(sprintf('%o', File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100744')
      end

      context 'when specific file permissions are requested' do
        let(:fingerprints_in_app_cache) do
          path = File.join(local_tmp_dir, 'content')
          sha = 'some_fake_sha'
          File.open(path, 'w') { |f| f.write 'content' }
          global_app_bits_cache.cp_to_blobstore(path, sha)

          CloudController::Blobstore::FingerprintsCollection.new([{ 'fn' => 'path/to/content.txt', 'size' => 123, 'sha1' => sha, 'mode' => mode }])
        end

        let(:mode) { '0653' }

        it 'uploads the old app bits with the requested permissions' do
          create

          package_blobstore.download_from_blobstore(app.guid, File.join(local_tmp_dir, 'package.zip'))
          `unzip #{local_tmp_dir}/package.zip path/to/content.txt -d #{local_tmp_dir}`
          expect(sprintf('%o', File.stat(File.join(local_tmp_dir, 'path/to/content.txt')).mode)).to eq('100653')
        end

        describe 'bad file permissions' do
          context 'when the write permissions are too-restrictive' do
            let(:mode) { '344' }

            it 'errors' do
              expect {
                create
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
                create
              }.to raise_error do |error|
                expect(error.name).to eq 'AppResourcesFileModeInvalid'
                expect(error.response_code).to eq 400
              end
            end
          end
        end
      end
    end

    it 'uploads the package zip to the package blob store' do
      create
      expect(package_blobstore.exists?(app.guid)).to be true
    end

    it 'sets the package sha to the app' do
      expect {
        create
      }.to change {
        app.refresh.package_hash
      }
    end

    it 'removes the compressed path afterwards' do
      expect(FileUtils).to receive(:rm_f).with(compressed_path)
      create
    end

    context 'when there is no package uploaded' do
      let(:compressed_path) { nil }

      it "doesn't try to remove the file" do
        expect(FileUtils).not_to receive(:rm_f)
        create
      end
    end

    context 'when the app bits are too large' do
      let(:max_package_size) { 10 }

      it 'raises an exception' do
        expect {
          create
        }.to raise_exception CloudController::Errors::ApiError, /package.+larger/i
      end

      it 'removes the compressed path afterwards' do
        expect(FileUtils).to receive(:rm_f).with(compressed_path)
        expect { create }.to raise_exception CloudController::Errors::ApiError, /package.+larger/i
      end
    end

    context 'when the max droplet size is not configured' do
      let(:max_package_size) { nil }

      it 'always accepts any droplet size' do
        fingerprints_in_app_cache = CloudController::Blobstore::FingerprintsCollection.new(
          [{ 'fn' => 'file.txt', 'size' => (2048 * 1024 * 1024) + 1, 'sha1' => 'a_sha' }]
        )
        packer.create(app, compressed_path, fingerprints_in_app_cache)
      end
    end
  end
end
