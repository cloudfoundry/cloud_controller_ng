require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe Messenger do
      let(:stager_client) { instance_double(StagerClient) }
      let(:nsync_client) { instance_double(NsyncClient) }
      let(:config) { TestConfig.config }
      let(:protocol) { instance_double('Traditional::Protocol') }
      let(:instances) { 3 }
      let(:default_health_check_timeout) { 9999 }

      let(:app) do
        app = AppFactory.make
        app.instances = instances
        app.health_check_timeout = 120
        app
      end

      subject(:messenger) { Messenger.new(app) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:stager_client).and_return(stager_client)
        allow(CloudController::DependencyLocator.instance).to receive(:nsync_client).and_return(nsync_client)
        allow(Diego::Protocol).to receive(:new).with(app).and_return(protocol)
      end

      describe '#send_stage_request' do
        let(:staging_guid) { StagingGuid.from_process(app) }
        let(:message) { { staging: 'message' } }

        before do
          allow(protocol).to receive(:stage_app_request).and_return(message)
          allow(stager_client).to receive(:stage)
        end

        it 'sends the staging message to the stager' do
          messenger.send_stage_request(config)

          expect(protocol).to have_received(:stage_app_request).with(config)
          expect(stager_client).to have_received(:stage).with(staging_guid, message)
        end
      end

      describe '#send_desire_request' do
        let(:process_guid) { ProcessGuid.from_process(app) }
        let(:message) { { desire: 'message' } }

        before do
          allow(protocol).to receive(:desire_app_request).and_return(message)
          allow(nsync_client).to receive(:desire_app)
        end

        it 'sends a desire app request' do
          messenger.send_desire_request(default_health_check_timeout)

          expect(protocol).to have_received(:desire_app_request).with(default_health_check_timeout)
          expect(nsync_client).to have_received(:desire_app).with(process_guid, message)
        end
      end

      describe '#send_stop_staging_request' do
        let(:staging_guid) { StagingGuid.from_process(app) }

        before do
          allow(stager_client).to receive(:stop_staging)
        end

        it 'sends a stop_staging request to the stager' do
          messenger.send_stop_staging_request

          expect(stager_client).to have_received(:stop_staging).with(staging_guid)
        end
      end

      describe '#send_stop_index_request' do
        let(:process_guid) { ProcessGuid.from_process(app) }
        let(:index) { 3 }

        before do
          allow(nsync_client).to receive(:stop_index)
        end

        it 'sends a stop index request' do
          messenger.send_stop_index_request(index)

          expect(nsync_client).to have_received(:stop_index).with(process_guid, index)
        end
      end

      describe '#send_stop_app_request' do
        let(:process_guid) { ProcessGuid.from_process(app) }

        before do
          allow(nsync_client).to receive(:stop_app)
        end

        it 'sends a stop app request' do
          messenger.send_stop_app_request

          expect(nsync_client).to have_received(:stop_app).with(process_guid)
        end
      end
    end
  end
end
