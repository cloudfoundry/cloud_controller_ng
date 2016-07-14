require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe Messenger do
      subject(:messenger) { Messenger.new }

      let(:stager_client) { instance_double(StagerClient) }
      let(:nsync_client) { instance_double(NsyncClient) }
      let(:config) { TestConfig.config }
      let(:protocol) { instance_double(Diego::Protocol) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:stager_client).and_return(stager_client)
        allow(CloudController::DependencyLocator.instance).to receive(:nsync_client).and_return(nsync_client)
        allow(Diego::Protocol).to receive(:new).and_return(protocol)
      end

      describe '#send_stage_request' do
        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(package: package) }
        let(:staging_guid) { droplet.guid }
        let(:message) { { staging: 'message' } }
        let(:staging_details) do
          VCAP::CloudController::Diego::StagingDetails.new.tap do |sd|
            sd.package = package
            sd.droplet = droplet
          end
        end

        before do
          allow(protocol).to receive(:stage_package_request).and_return(message)
          allow(stager_client).to receive(:stage)
        end

        it 'sends the staging message to the stager' do
          messenger.send_stage_request(config, staging_details)

          expect(protocol).to have_received(:stage_package_request).with(config, staging_details)
          expect(stager_client).to have_received(:stage).with(staging_guid, message)
        end
      end

      describe '#send_desire_request' do
        let(:process) { App.new }
        let(:default_health_check_timeout) { 9999 }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:message) { { desire: 'message' } }

        before do
          allow(protocol).to receive(:desire_app_request).and_return(message)
          allow(nsync_client).to receive(:desire_app)
        end

        it 'sends a desire app request' do
          messenger.send_desire_request(process, default_health_check_timeout)

          expect(protocol).to have_received(:desire_app_request).with(process, default_health_check_timeout)
          expect(nsync_client).to have_received(:desire_app).with(process_guid, message)
        end
      end

      describe '#send_stop_staging_request' do
        let(:staging_guid) { 'whatever' }

        before do
          allow(stager_client).to receive(:stop_staging)
        end

        it 'sends a stop_staging request to the stager' do
          messenger.send_stop_staging_request(staging_guid)

          expect(stager_client).to have_received(:stop_staging).with(staging_guid)
        end
      end

      describe '#send_stop_index_request' do
        let(:process) { App.new }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:index) { 3 }

        before do
          allow(nsync_client).to receive(:stop_index)
        end

        it 'sends a stop index request' do
          messenger.send_stop_index_request(process, index)

          expect(nsync_client).to have_received(:stop_index).with(process_guid, index)
        end
      end

      describe '#send_stop_app_request' do
        let(:process) { App.new }
        let(:process_guid) { ProcessGuid.from_process(process) }

        before do
          allow(nsync_client).to receive(:stop_app)
        end

        it 'sends a stop app request' do
          messenger.send_stop_app_request(process)

          expect(nsync_client).to have_received(:stop_app).with(process_guid)
        end
      end
    end
  end
end
