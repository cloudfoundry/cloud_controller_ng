require 'spec_helper'
require 'cloud_controller/kpack/stager'
require 'kubernetes/kpack_client'

module Kpack
  RSpec.describe Stager do
    subject(:stager) { Stager.new(
      builder_namespace: 'namespace',
      registry_service_account_name: 'gcr-service-account',
      registry_tag_base: 'gcr.io/capi-images'
    )
    }
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:environment_variables) { { 'nightshade_vegetable' => 'potato' } }
    let(:staging_memory_in_mb) { 1024 }
    let(:staging_disk_in_mb) { 1024 }
    let(:blobstore_url_generator) do
      instance_double(::CloudController::Blobstore::UrlGenerator,
        package_download_url: 'package-download-url',
      )
    end
    let(:client) { instance_double(Kubernetes::KpackClient) }
    before do
      allow(CloudController::DependencyLocator.instance).to receive(:kpack_client).and_return(client)
      allow(CloudController::DependencyLocator.instance).to receive(:blobstore_url_generator).and_return(blobstore_url_generator)
    end

    it_behaves_like 'a stager'

    describe '#stage' do
      let(:staging_details) do
        details = VCAP::CloudController::Diego::StagingDetails.new
        details.package = package
        details.environment_variables = environment_variables
        details.staging_memory_in_mb = staging_memory_in_mb
        details.staging_disk_in_mb = staging_disk_in_mb
        details.staging_guid = build.guid
        details.lifecycle = lifecycle
        details
      end

      let(:lifecycle) do
        VCAP::CloudController::KpackLifecycle.new(package, {})
      end

      let(:build) { VCAP::CloudController::BuildModel.make(:kpack) }

      it 'creates an image using the kpack client' do
        expect(client).to receive(:create_image).with(Kubeclient::Resource.new({
          metadata: {
            name: package.guid,
            namespace: 'namespace',
            labels: {
              Stager::APP_GUID_LABEL_KEY => package.app.guid,
            }
          },
          spec: {
            tag: "gcr.io/capi-images/#{package.guid}",
            serviceAccount: 'gcr-service-account',
            builder: {
              name: 'capi-builder',
              kind: 'Builder'
            },
            source: {
              blob: {
                url: 'package-download-url',
              }
            }
          }
        }))

        stager.stage(staging_details)
        expect(blobstore_url_generator).to have_received(:package_download_url).with(package)
      end
    end
  end
end
