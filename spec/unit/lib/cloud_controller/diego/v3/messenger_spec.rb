require 'spec_helper'
require 'cloud_controller/diego/traditional/v3/protocol'
require 'cloud_controller/diego/v3/messenger'

module VCAP::CloudController
  module Diego
    module V3
      describe Messenger do
        let(:stager_client) { instance_double(StagerClient) }
        let(:nsync_client) { instance_double(NsyncClient) }
        let(:config) { TestConfig.config }
        let(:protocol) { instance_double(Traditional::V3::Protocol) }
        let(:default_health_check_timeout) { 9999 }

        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(package_guid: package.guid) }

        subject(:messenger) { Messenger.new(stager_client, nsync_client, protocol) }

        describe '#send_stage_request' do
          let(:staging_guid) { droplet.guid }
          let(:message) { { staging: 'message' } }
          let(:staging_details) do
            details = VCAP::CloudController::Diego::Traditional::V3::StagingDetails.new
            details.droplet = droplet
            details
          end

          before do
            allow(protocol).to receive(:stage_package_request).and_return(message)
            allow(stager_client).to receive(:stage)
          end

          it 'sends the staging message to the stager' do
            messenger.send_stage_request(package, config, staging_details)

            expect(protocol).to have_received(:stage_package_request).with(package, config, staging_details)
            expect(stager_client).to have_received(:stage).with(staging_guid, message)
          end
        end
      end
    end
  end
end
