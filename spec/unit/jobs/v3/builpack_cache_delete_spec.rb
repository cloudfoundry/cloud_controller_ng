require 'spec_helper'
require 'jobs/v3/buildpack_cache_delete'

module VCAP::CloudController
  module Jobs::V3
    describe BuildpackCacheDelete do
      let(:app_guid) { 'some-guid' }
      let!(:blobstore) { CloudController::DependencyLocator.instance.buildpack_cache_blobstore }
      let(:tmpfile) { Tempfile.new('') }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:buildpack_cache_blobstore).and_return(blobstore)
        blobstore.cp_to_blobstore(tmpfile.path, "#{app_guid}-stack1")
        blobstore.cp_to_blobstore(tmpfile.path, "#{app_guid}-stack2")
        blobstore.cp_to_blobstore(tmpfile.path, 'other-guid-stack1')
      end

      after do
        tmpfile.delete
      end

      subject(:job) { BuildpackCacheDelete.new(app_guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'deletes all matching blobs' do
          expect(blobstore.exists?("#{app_guid}-stack1")).to be_truthy
          expect(blobstore.exists?("#{app_guid}-stack2")).to be_truthy
          expect(blobstore.exists?('other-guid-stack1')).to be_truthy

          job.perform

          expect(blobstore.exists?("#{app_guid}-stack1")).to be_falsey
          expect(blobstore.exists?("#{app_guid}-stack2")).to be_falsey
          expect(blobstore.exists?('other-guid-stack1')).to be_truthy
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_cache_delete)
        end
      end
    end
  end
end
