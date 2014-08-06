require "spec_helper"

module VCAP::CloudController
  module Diego
    describe StagingRequest do
      let(:blobstore_url_generator) do
        instance_double(CloudController::Blobstore::UrlGenerator,
          :buildpack_cache_download_url => "http://buildpack-artifacts-cache.com",
          :app_package_download_url => "http://app-package.com",
        )
      end

      let(:buildpack_entry_generator) do
        BuildpackEntryGenerator.new(blobstore_url_generator)
      end

      let(:app) do
        AppFactory.make
      end

      subject(:staging_request) do
        StagingRequest.new(app, blobstore_url_generator, buildpack_entry_generator)
      end

      before do
        app.update(staging_task_id: "fake-staging-task-id")
      end

      it "sends a nats message with the appropriate staging subject and payload" do
        expect(staging_request.to_h).to eq(
          :app_id => app.guid,
          :task_id => "fake-staging-task-id",
          :memory_mb => app.memory,
          :disk_mb => app.disk_quota,
          :file_descriptors => app.file_descriptors,
          :environment => Environment.new(app).to_a,
          :stack => app.stack.name,
          :build_artifacts_cache_download_uri => "http://buildpack-artifacts-cache.com",
          :app_bits_download_uri => "http://app-package.com",
          :buildpacks => buildpack_entry_generator.buildpack_entries(app)
        )
      end
    end
  end
end
