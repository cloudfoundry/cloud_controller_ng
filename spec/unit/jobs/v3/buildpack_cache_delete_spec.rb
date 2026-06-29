require 'spec_helper'
require 'jobs/v3/buildpack_cache_delete'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe BuildpackCacheDelete, job_context: :worker do
      let(:app_guid) { 'some-guid' }
      let!(:blobstore) do
        CloudController::Blobstore::FogClient.new(connection_config: { provider: 'AWS', aws_access_key_id: 'fake', aws_secret_access_key: 'fake' },
                                                  directory_key: 'directory_key')
      end
      let(:path_1) { Presenters::V3::CacheKeyPresenter.cache_key(guid: app_guid, stack_name: 'stack1') }
      let(:path_2) { Presenters::V3::CacheKeyPresenter.cache_key(guid: app_guid, stack_name: 'stack2') }
      let(:path_3) { Presenters::V3::CacheKeyPresenter.cache_key(guid: 'other-guid', stack_name: 'stack3') }

      before do
        blobstore.ensure_bucket_exists
        Tempfile.create('cache_file') do |f|
          allow(CloudController::DependencyLocator.instance).to receive(:buildpack_cache_blobstore).and_return(blobstore)
          blobstore.cp_to_blobstore(f.path, path_1)
          blobstore.cp_to_blobstore(f.path, path_2)
          blobstore.cp_to_blobstore(f.path, path_3)
        end
      end

      after do
        Fog::Mock.reset
      end

      subject(:job) { BuildpackCacheDelete.new(app_guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'deletes all matching blobs' do
          expect(blobstore).to exist(path_1)
          expect(blobstore).to exist(path_2)
          expect(blobstore).to exist(path_3)

          job.perform

          expect(blobstore).not_to exist(path_1)
          expect(blobstore).not_to exist(path_2)
          expect(blobstore).to exist(path_3)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_cache_delete)
        end
      end

      describe '#display_name' do
        it 'returns the correct display name' do
          expect(job.display_name).to eq('app.clear_buildpack_cache')
        end
      end
    end
  end
end
