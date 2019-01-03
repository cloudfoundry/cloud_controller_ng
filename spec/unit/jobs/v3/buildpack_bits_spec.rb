require 'spec_helper'
require 'jobs/v3/buildpack_bits'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe BuildpackBits, job_context: :api do
      let(:uploaded_path) { 'tmp/random-nginx-filename-1020930' }
      let(:filename) { 'buildpack.zip' }
      let!(:buildpack) { Buildpack.make }
      let(:buildpack_guid) { buildpack.guid }

      subject(:job) do
        BuildpackBits.new(buildpack_guid, uploaded_path, filename)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'creates a blobstore client and performs' do
          uploader = instance_double(UploadBuildpack)
          expect(UploadBuildpack).to receive(:new).with(instance_of(CloudController::Blobstore::Client)).and_return(uploader)
          expect(uploader).to receive(:upload_buildpack).with(buildpack, uploaded_path, filename)
          expect(FileUtils).to receive(:rm_f).with(uploaded_path)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_bits)
        end
      end
    end
  end
end
