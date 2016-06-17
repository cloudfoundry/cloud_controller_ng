require 'spec_helper'
require 'cloud_controller/diego/v3/protocol/package_staging_protocol'
require 'cloud_controller/diego/v3/messenger'

module VCAP::CloudController
  module Diego
    module V3
      RSpec.describe Messenger do
        let(:stager_client) { instance_double(StagerClient) }
        let(:config) { TestConfig.config }
        let(:protocol) { instance_double(V3::Protocol::PackageStagingProtocol) }
        let(:default_health_check_timeout) { 9999 }

        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(package_guid: package.guid) }

        subject(:messenger) { Messenger.new(protocol) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:stager_client).and_return(stager_client)
        end

        describe '#send_stage_request' do
          let(:staging_guid) { droplet.guid }
          let(:message) { { staging: 'message' } }
          let(:staging_details) do
            details = VCAP::CloudController::Diego::V3::StagingDetails.new
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
