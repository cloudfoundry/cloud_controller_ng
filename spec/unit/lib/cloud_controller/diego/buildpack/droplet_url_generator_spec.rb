require 'spec_helper'
require 'cloud_controller/diego/buildpack/droplet_url_generator'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DropletUrlGenerator do
        let(:hostname) { 'api.internal.cf' }
        let(:external_port) { 8181 }
        let(:tls_port) { 8182 }
        let(:mtls) { false }

        subject(:generator) do
          described_class.new(
            internal_service_hostname: hostname,
            external_port:             external_port,
            tls_port:                  tls_port,
            mtls:                      mtls
          )
        end

        describe '#perma_droplet_download_url' do
          let(:app_guid) { 'random-guid' }
          let(:droplet_checksum) { '12345' }

          it 'gives out a url to the cloud controller' do
            download_url = "http://api.internal.cf:8181/internal/v2/droplets/#{app_guid}/#{droplet_checksum}/download"
            expect(generator.perma_droplet_download_url(app_guid, droplet_checksum)).to eql(download_url)
          end

          context 'when no droplet_hash' do
            it 'returns nil if no droplet_hash' do
              expect(generator.perma_droplet_download_url(app_guid, nil)).to be_nil
            end
          end

          context 'when mTLS is enabled' do
            let(:mtls) { true }

            it 'gives out a url to the cloud controller using mTLS' do
              download_url = "https://api.internal.cf:8182/internal/v4/droplets/#{app_guid}/#{droplet_checksum}/download"
              expect(generator.perma_droplet_download_url(app_guid, droplet_checksum)).to eql(download_url)
            end
          end
        end
      end
    end
  end
end
