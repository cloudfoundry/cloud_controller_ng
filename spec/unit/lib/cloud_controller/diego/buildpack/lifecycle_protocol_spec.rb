require 'spec_helper'
require_relative '../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        describe LifecycleProtocol do
          let(:blobstore_url_generator) do
            instance_double(::CloudController::Blobstore::UrlGenerator).tap do |url_generator|
              allow(url_generator).to receive(:app_package_download_url).and_return('')
              allow(url_generator).to receive(:buildpack_cache_download_url).and_return('')
              allow(url_generator).to receive(:buildpack_cache_upload_url).and_return('')
              allow(url_generator).to receive(:droplet_upload_url).and_return('')
              allow(url_generator).to receive(:unauthorized_perma_droplet_download_url).and_return('')
            end
          end
          let(:lifecycle_protocol) { LifecycleProtocol.new(blobstore_url_generator) }
          let(:app) { App.make }

          it_behaves_like 'a lifecycle protocol' do
            let(:app) { App.make }
          end

          describe '#lifecycle_data' do
            let(:buildpack_url) { 'http://example.com/buildpack' }
            let(:config) { TestConfig.config }

            before do
              VCAP::CloudController::Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)

              allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return(buildpack_url)
            end

            it 'returns lifecycle data of type buildpack' do
              type = lifecycle_protocol.lifecycle_data(app)[0]
              expect(type).to eq('buildpack')
            end

            context 'when auto-detecting' do
              it 'sends buildpacks without skip_detect' do
                message = lifecycle_protocol.lifecycle_data(app)[1]

                expect(message[:buildpacks]).to have(1).items
                buildpack = message[:buildpacks][0]
                expect(buildpack).to include(name: 'ruby')
                expect(buildpack).to_not include(:skip_detect)
              end
            end

            context 'when a buildpack is requested' do
              before do
                app.buildpack = 'ruby'
              end

              it 'sends buildpacks with skip detect' do
                message = lifecycle_protocol.lifecycle_data(app)[1]

                expect([:buildpacks]).to have(1).items
                buildpack = message[:buildpacks][0]
                expect(buildpack).to include(name: 'ruby', skip_detect: true)
              end
            end

            context 'when a custom buildpack is requested' do
              let(:buildpack_url) { 'http://example.com/buildpack' }
              before do
                app.buildpack = buildpack_url
              end

              it 'sends buildpacks with skip detect' do
                message = lifecycle_protocol.lifecycle_data(app)[1]

                expect(message[:buildpacks]).to have(1).items
                buildpack = message[:buildpacks][0]
                expect(buildpack).to include(url: buildpack_url, skip_detect: true)
              end
            end
          end

          describe '#desired_app_message' do
            context 'when app has a start command set' do
              before do
                app.command = 'command from app'
                app.save
              end

              it 'uses it' do
                start_command = lifecycle_protocol.desired_app_message(app)['start_command']
                expect(start_command).to eq('command from app')
              end
            end

            context 'when app does not have a start command set' do
              before do
                app.command = ''
                app.save
                app.add_new_droplet('meowmeowmeow')
                app.current_droplet.detected_start_command = 'command from droplet'
                app.current_droplet.save
              end

              it 'uses the droplet detected start command' do
                start_command = lifecycle_protocol.desired_app_message(app)['start_command']
                expect(start_command).to eq('command from droplet')
              end
            end

            context 'droplet_uri' do
              before do
                allow(blobstore_url_generator).to receive(:unauthorized_perma_droplet_download_url).and_return('www.droplet.com')
              end

              it 'includes the droplet_uri' do
                droplet_uri = lifecycle_protocol.desired_app_message(app)['droplet_uri']

                expect(droplet_uri).to eq('www.droplet.com')
              end
            end
          end
        end
      end
    end
  end
end
