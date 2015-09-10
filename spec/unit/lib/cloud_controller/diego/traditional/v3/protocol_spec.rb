require 'spec_helper'
require 'cloud_controller/diego/traditional/v3/protocol'

module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        describe Protocol do
          let(:blobstore_url_generator) do
            instance_double(CloudController::Blobstore::UrlGenerator,
              buildpack_cache_download_url:            'http://buildpack-artifacts-cache.com',
              app_package_download_url:                'http://app-package.com',
              unauthorized_perma_droplet_download_url: 'fake-droplet_uri',
              buildpack_cache_upload_url:              'http://buildpack-artifacts-cache.up.com',
              droplet_upload_url:                      'http://droplet-upload-uri',
            )
          end

          let(:default_health_check_timeout) { 99 }
          let(:egress_rules) { double(:egress_rules) }

          subject(:protocol) do
            Protocol.new(blobstore_url_generator, egress_rules)
          end

          before do
            allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
          end

          describe '#stage_package_request' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }
            let(:buildpack_info) { BuildpackRequestValidator.new({ buildpack: 'http://awesome-pack.io' }) }
            let(:staging_details) { instance_double(StagingDetails) }
            let(:config) { 'the-config' }

            before do
              allow(protocol).to receive(:stage_package_message).and_return(hello: 'goodbye')
            end

            let(:request) { protocol.stage_package_request(package, config, staging_details) }

            it 'returns the staging request message to be used by the stager client as json' do
              expect(request).to eq('{"hello":"goodbye"}')
            end
          end

          describe '#stage_package_message' do
            let(:app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: app.guid) }
            let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: app.guid) }
            let(:buildpack_info) { BuildpackRequestValidator.new({ buildpack: 'http://awesome-pack.io' }) }
            let(:staging_details) do
              details                       = StagingDetails.new
              details.droplet               = droplet
              details.stack                 = 'potato-stack'
              details.environment_variables = { 'nightshade_fruit' => 'potato' }
              details.memory_limit          = 42
              details.disk_limit            = 51
              details.buildpack_info        = buildpack_info
              details
            end
            let(:config) do
              {
                external_port:             external_port,
                internal_service_hostname: internal_service_hostname,
                internal_api:              {
                  auth_user:     user,
                  auth_password: password
                },
                staging:                   {
                  minimum_staging_memory_mb:             128,
                  minimum_staging_file_descriptor_limit: 30,
                  timeout_in_seconds:                    90,
                }
              }
            end
            let(:blobstore_url_generator) do
              instance_double(CloudController::Blobstore::UrlGenerator,
                v3_app_buildpack_cache_download_url: 'cache-download-url',
                v3_app_buildpack_cache_upload_url:   'cache-upload-url',
                package_download_url:                'package-download-url',
                package_droplet_upload_url:          'droplet-upload-url'
              )
            end
            let(:internal_service_hostname) { 'internal.awesome.sauce' }
            let(:external_port) { '7777' }
            let(:user) { 'user' }
            let(:password) { 'password' }

            let(:buildpack_generator) { V3::BuildpackEntryGenerator.new(blobstore_url_generator) }

            before do
              buildpack_info.valid?
            end

            it 'contains the correct payload for staging a package' do
              result = protocol.stage_package_message(package, config, staging_details)

              expect(result).to eq({
                    app_id:           staging_details.droplet.guid,
                    log_guid:         app.guid,
                    memory_mb:        staging_details.memory_limit,
                    disk_mb:          staging_details.disk_limit,
                    file_descriptors: 30,
                    environment:      VCAP::CloudController::Diego::Environment.hash_to_diego_env(staging_details.environment_variables),
                    egress_rules:     ['staging_egress_rule'],
                    timeout:          90,
                    lifecycle:        'buildpack',
                    lifecycle_data:   {
                      build_artifacts_cache_download_uri: 'cache-download-url',
                      build_artifacts_cache_upload_uri:   'cache-upload-url',
                      app_bits_download_uri:              'package-download-url',
                      droplet_upload_uri:                 'droplet-upload-url',
                      buildpacks:                         buildpack_generator.buildpack_entries(buildpack_info),
                      stack:                              'potato-stack',
                    },
                    completion_callback:    "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/staging/#{droplet.guid}/droplet_completed"
                  })
            end

            describe 'buildpack payload' do
              let(:buildpack_info) { BuildpackRequestValidator.new({ buildpack: buildpack }) }

              before do
                staging_details.buildpack_info.valid?
                Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)
                allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return('bp-download-url')
              end

              context 'when auto-detecting' do
                let(:buildpack) { nil }

                it 'sends buildpacks without skip_detect' do
                  message = protocol.stage_package_message(package, config, staging_details)

                  expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                  bp = message[:lifecycle_data][:buildpacks][0]
                  expect(bp).to include(name: 'ruby')
                  expect(bp).to_not include(:skip_detect)
                end
              end

              context 'when a buildpack is requested' do
                let(:buildpack) { 'ruby' }

                it 'sends buildpacks with skip detect' do
                  message = protocol.stage_package_message(package, config, staging_details)

                  expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                  bp = message[:lifecycle_data][:buildpacks][0]
                  expect(bp).to include(name: 'ruby', skip_detect: true)
                end
              end

              context 'when a custom buildpack is requested' do
                let(:buildpack) { 'http://custom.com' }

                it 'sends buildpacks with skip detect' do
                  message = protocol.stage_package_message(package, config, staging_details)

                  expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                  bp = message[:lifecycle_data][:buildpacks][0]
                  expect(bp).to include(url: buildpack, skip_detect: true)
                end
              end
            end
          end
        end
      end
    end
  end
end
