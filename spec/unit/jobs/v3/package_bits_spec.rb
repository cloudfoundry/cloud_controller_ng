require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe PackageBits, job_context: :api do
      let(:uploaded_path) { 'tmp/uploaded.zip' }
      let(:package_guid) { SecureRandom.uuid }
      let(:fingerprints) { [:fingerprint] }
      let(:background_logger) { instance_double(Steno::Logger, info: nil) }

      subject(:job) do
        PackageBits.new(package_guid, uploaded_path, fingerprints)
      end

      before do
        allow(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:package_blobstore) { instance_double(CloudController::Blobstore::Client) }
        let(:tmpdir) { '/tmp/special_temp' }
        let(:max_package_size) { 256 }

        it 'creates an PackagePacker and performs' do
          packer = instance_double(CloudController::Packager::PackageUploadHandler)
          expect(CloudController::Packager::PackageUploadHandler).to receive(:new).with(package_guid, uploaded_path, fingerprints).and_return(packer)
          expect(packer).to receive(:pack)
          job.perform
        end

        it 'logs start and completion' do
          allow_any_instance_of(CloudController::Packager::PackageUploadHandler).to receive(:pack)

          job.perform

          expect(background_logger).to have_received(:info).with('package_upload.job.start',
                                                                 hash_including(package_guid: package_guid, package_zip_path_present: true, fingerprint_count: 1))
          expect(background_logger).to have_received(:info).with('package_upload.job.done', hash_including(package_guid: package_guid, duration_ms: be >= 0))
        end

        it 'logs failure details and re-raises' do
          allow_any_instance_of(CloudController::Packager::PackageUploadHandler).to receive(:pack).and_raise(StandardError.new('boom'))

          expect { job.perform }.to raise_error(StandardError, 'boom')

          expect(background_logger).to have_received(:info).with('package_upload.job.failed',
                                                                 hash_including(package_guid: package_guid, error_class: 'StandardError', error: 'boom'))
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:package_bits)
        end
      end

      describe 'pollable job metadata' do
        it 'exposes the package guid as resource_guid' do
          expect(job.resource_guid).to eq(package_guid)
        end

        it 'has a display_name' do
          expect(job.display_name).to eq('package.upload')
        end

        it 'has a resource_type' do
          expect(job.resource_type).to eq('package')
        end
      end
    end
  end
end
