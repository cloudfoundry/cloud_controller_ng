require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe AppBitsPacker do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:app_guid) { SecureRandom.uuid }

      subject(:job) do
        AppBitsPacker.new(app_guid, uploaded_path, [:fingerprints])
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:app) { double(:app) }
        let(:fingerprints) { double(:fingerprints) }
        let(:package_blobstore) { double(:package_blobstore) }
        let(:global_app_bits_cache) { double(:global_app_bits_cache) }
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        before do
          TestConfig.override({ directories: { tmpdir: tmpdir }, packages: TestConfig.config[:packages].merge(max_package_size: max_package_size) })

          allow(CloudController::Blobstore::FingerprintsCollection).to receive(:new) { fingerprints }
          allow(App).to receive(:find) { app }
          allow(AppBitsPackage).to receive(:new) { double(:packer, create: 'done') }
        end

        it 'finds the app from the guid' do
          expect(App).to receive(:find).with(guid: app_guid)
          job.perform
        end

        it 'creates blob stores' do
          expect(CloudController::DependencyLocator.instance).to receive(:package_blobstore)
          expect(CloudController::DependencyLocator.instance).to receive(:global_app_bits_cache)
          job.perform
        end

        it 'creates an app bit packer and performs' do
          expect(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          expect(CloudController::DependencyLocator.instance).to receive(:global_app_bits_cache).and_return(global_app_bits_cache)

          packer = double
          expect(AppBitsPackage).to receive(:new).with(package_blobstore, global_app_bits_cache, max_package_size, tmpdir).and_return(packer)
          expect(packer).to receive(:create).with(app, uploaded_path, fingerprints)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:app_bits_packer)
        end
      end
    end
  end
end
