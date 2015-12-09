require 'spec_helper'
require 'cloud_controller/blobstore/url_generator'
require 'cloud_controller/diego/buildpack/v3/lifecycle_protocol'
require_relative '../../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        module V3
          describe LifecycleProtocol do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }

            subject(:lifecycle_protocol) { LifecycleProtocol.new(blobstore_url_generator) }
            it_behaves_like 'a v3 lifecycle protocol' do
              let(:app) { AppModel.make }
              let(:package) { PackageModel.make(app_guid: app.guid) }
              let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }

              let(:staging_details) do
                Diego::V3::StagingDetails.new.tap do |details|
                  details.droplet               = droplet
                  details.lifecycle             = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: buildpack_info)
                end
              end
            end

            let(:blobstore_url_generator) do
              instance_double(::CloudController::Blobstore::UrlGenerator,
                v3_app_buildpack_cache_download_url: 'cache-download-url',
                v3_app_buildpack_cache_upload_url:   'cache-upload-url',
                package_download_url:                'package-download-url',
                package_droplet_upload_url:          'droplet-upload-url'
              )
            end

            let(:buildpack_generator) { V3::BuildpackEntryGenerator.new(blobstore_url_generator) }
            let(:buildpack) { nil }
            let(:buildpack_info) { BuildpackInfo.new(buildpack, VCAP::CloudController::Buildpack.find(name: buildpack)) }

            let(:staging_details) do
              Diego::V3::StagingDetails.new.tap do |details|
                details.droplet               = droplet
                details.environment_variables = { 'nightshade_fruit' => 'potato' }
                details.memory_limit          = 42
                details.disk_limit            = 51
                details.lifecycle             = instance_double(BuildpackLifecycle, staging_stack: 'potato-stack', buildpack_info: buildpack_info)
              end
            end

            before do
              VCAP::CloudController::Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)
              allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return('bp-download-url')
            end

            context 'when auto-detecting' do
              it 'sends buildpacks without skip_detect' do
                _, lifecycle_data = lifecycle_protocol.lifecycle_data(package, staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(name: 'ruby')
                expect(bp).to_not include(:skip_detect)
              end
            end

            context 'when a buildpack is requested' do
              let(:buildpack) { 'ruby' }

              it 'sends buildpacks with skip detect' do
                _, lifecycle_data = lifecycle_protocol.lifecycle_data(package, staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(name: 'ruby', skip_detect: true)
              end
            end

            context 'when a custom buildpack is requested' do
              let(:buildpack) { 'http://custom.com' }

              it 'sends buildpacks with skip detect' do
                _, lifecycle_data = lifecycle_protocol.lifecycle_data(package, staging_details)

                expect(lifecycle_data[:buildpacks]).to have(1).items
                bp = lifecycle_data[:buildpacks][0]
                expect(bp).to include(url: buildpack, skip_detect: true)
              end
            end
          end
        end
      end
    end
  end
end
