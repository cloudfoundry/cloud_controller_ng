require 'spec_helper'
require 'jobs/v3/buildpack_cache_delete'

module VCAP::CloudController
  module Jobs::V3
    describe BuildpackCacheDelete do
      let(:app_guid) { 'some-guid' }
      let(:local_dir) { Dir.mktmpdir }
      let!(:blobstore) { CloudController::Blobstore::Client.new({ provider: 'Local', local_root: local_dir }, 'directory_key') }

      let(:path_1) { CacheKeyPresenter.cache_key(guid: app_guid, stack_name: 'stack1') }
      let(:path_2) { CacheKeyPresenter.cache_key(guid: app_guid, stack_name: 'stack2') }
      let(:path_3) { CacheKeyPresenter.cache_key(guid: 'other-guid', stack_name: 'stack3') }

      before do
        Fog.unmock!
        path = File.join(local_dir, 'empty_file')
        FileUtils.touch(path)

        allow(CloudController::DependencyLocator.instance).to receive(:buildpack_cache_blobstore).and_return(blobstore)
        blobstore.cp_to_blobstore(path, path_1)
        blobstore.cp_to_blobstore(path, path_2)
        blobstore.cp_to_blobstore(path, path_3)
      end

      after do
        Fog.mock!
      end

      subject(:job) { BuildpackCacheDelete.new(app_guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'deletes all matching blobs' do
          expect(blobstore.exists?(path_1)).to be_truthy
          expect(blobstore.exists?(path_2)).to be_truthy
          expect(blobstore.exists?(path_3)).to be_truthy

          job.perform

          expect(blobstore.exists?(path_1)).to be_falsey
          expect(blobstore.exists?(path_2)).to be_falsey
          expect(blobstore.exists?(path_3)).to be_truthy
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_cache_delete)
        end
      end
    end
  end
end
