require 'spec_helper'
require 'cloud_controller/diego/buildpack/droplet_url_generator'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DropletUrlGenerator do
        subject(:generator) { described_class.new }

        describe '#perma_droplet_download_url' do
          let(:app) { VCAP::CloudController::AppFactory.make }

          it 'gives out a url to the cloud controller' do
            download_url = "http://api.internal.cf:8181/internal/v2/droplets/#{app.guid}/#{app.droplet_checksum}/download"
            expect(generator.perma_droplet_download_url(app)).to eql(download_url)
          end

          context 'when no droplet_hash' do
            before do
              app.current_droplet.destroy
              app.reload
            end

            it 'returns nil if no droplet_hash' do
              expect(generator.perma_droplet_download_url(app)).to be_nil
            end
          end

          context 'when temporary_droplet_download_mtls is enabled' do
            before do
              TestConfig.override({ diego: { temporary_droplet_download_mtls: true } })
            end

            it 'gives out a url to the cloud controller using mTLS' do
              download_url = "https://api.internal.cf:8182/internal/v4/droplets/#{app.guid}/#{app.droplet_checksum}/download"
              expect(generator.perma_droplet_download_url(app)).to eql(download_url)
            end
          end
        end
      end
    end
  end
end
