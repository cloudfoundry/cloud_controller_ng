require 'spec_helper'
require 'cloud_controller/diego/droplet_url_generator'

module VCAP::CloudController
  module Diego
    RSpec.describe DropletUrlGenerator do
      let(:hostname) { 'api.internal.cf' }
      let(:tls_port) { 8182 }

      subject(:generator) do
        DropletUrlGenerator.new(
          internal_service_hostname: hostname,
          tls_port: tls_port
        )
      end

      describe '#perma_droplet_download_url' do
        let(:app_guid) { 'random-guid' }
        let(:droplet_checksum) { '12345' }

        it 'gives out an mTLS url to the cloud controller' do
          download_url = "https://api.internal.cf:8182/internal/v4/droplets/#{app_guid}/#{droplet_checksum}/download"
          expect(generator.perma_droplet_download_url(app_guid, droplet_checksum)).to eql(download_url)
        end

        context 'when no droplet_hash' do
          it 'returns nil if no droplet_hash' do
            expect(generator.perma_droplet_download_url(app_guid, nil)).to be_nil
          end
        end
      end
    end
  end
end
