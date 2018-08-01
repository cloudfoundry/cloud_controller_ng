require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackCacheCleanup do
      let(:cc_addr) { '1.2.3.4' }
      let(:cc_port) { 5678 }
      let(:orphan_key) { 'orphan-key' }
      let(:buildpack_cache_key) { 'another-cache-key' }
      let(:droplet_key) { 'droplet-key' }
      let(:file) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:workspace) { Dir.mktmpdir }

      let(:blobstore_config) do
        {
          external_host: cc_addr,
          external_port: cc_port,
          droplets: {
            droplet_directory_key: 'cc-droplets',
            fog_connection: {
              provider: 'Local',
              local_root: Dir.mktmpdir('droplets', workspace)
            }
          },
          directories: {
            tmpdir: Dir.mktmpdir('tmpdir', workspace)
          },
          index: 99,
          name: 'api_z1'
        }
      end

      subject(:job) do
        BuildpackCacheCleanup.new
      end

      before do
        TestConfig.override(blobstore_config)
      end

      let(:blobstore) do
        CloudController::DependencyLocator.instance.buildpack_cache_blobstore
      end

      let(:droplet_blobstore) do
        CloudController::DependencyLocator.instance.droplet_blobstore
      end

      after do
        FileUtils.rm_rf(workspace)
      end

      it 'deletes everything from the buildpack_cache directory' do
        Fog.unmock!
        blobstore.cp_to_blobstore(file, orphan_key)
        blobstore.cp_to_blobstore(file, buildpack_cache_key)

        expect(blobstore.exists?(orphan_key)).to be_truthy
        expect(blobstore.exists?(buildpack_cache_key)).to be_truthy

        job.perform

        expect(blobstore.exists?(orphan_key)).to be_falsey
        expect(blobstore.exists?(buildpack_cache_key)).to be_falsey
      end

      it 'does not delete any droplets' do
        Fog.unmock!
        blobstore.cp_to_blobstore(file, orphan_key)
        droplet_blobstore.cp_to_blobstore(file, droplet_key)

        expect(blobstore.exists?(orphan_key)).to be_truthy
        expect(droplet_blobstore.exists?(droplet_key)).to be_truthy

        job.perform

        expect(blobstore.exists?(orphan_key)).to be_falsey
        expect(droplet_blobstore.exists?(droplet_key)).to be_truthy
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:buildpack_cache_cleanup)
      end
    end
  end
end
