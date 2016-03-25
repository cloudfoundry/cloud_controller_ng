require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe AppBitsPacker do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:app) { App.make }
      let(:app_guid) { app.guid }

      subject(:job) do
        AppBitsPacker.new(app_guid, uploaded_path, [:fingerprints])
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:fingerprints) { double(:fingerprints) }
        let(:package_blobstore) { double(:package_blobstore) }
        let(:global_app_bits_cache) { double(:global_app_bits_cache) }
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        before do
          TestConfig.override({ directories: { tmpdir: tmpdir }, packages: TestConfig.config[:packages].merge(max_package_size: max_package_size) })

          allow(CloudController::Blobstore::FingerprintsCollection).to receive(:new) { fingerprints }
          allow(AppBitsPackage).to receive(:new) { double(:packer, create: 'done') }
        end

        it 'creates an app bit packer and performs' do
          packer = double(:packer)
          expect(AppBitsPackage).to receive(:new).and_return(packer)
          expect(packer).to receive(:create).with(app, uploaded_path, fingerprints)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:app_bits_packer)
        end

        it 'logs an error if the app cannot be found' do
          app.destroy

          logger = double(:logger, error: nil, info: nil)
          allow(job).to receive(:logger).and_return(logger)

          job.perform

          expect(logger).to have_received(:error).with("App not found: #{app_guid}")
        end
      end
    end
  end
end
