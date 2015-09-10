require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Messenger do
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

      subject(:messenger) { Messenger.new(stager_client, nsync_client, protocol) }

      describe '#send_stage_request' do
        let(:staging_guid) { StagingGuid.from_app(app) }
        let(:message) { { staging: 'message' } }

        before do
          allow(protocol).to receive(:stage_app_request).and_return(message)
          allow(stager_client).to receive(:stage)
        end

        it 'sends the staging message to the stager' do
          messenger.send_stage_request(app, config)

          expect(protocol).to have_received(:stage_app_request).with(app, config)
          expect(stager_client).to have_received(:stage).with(staging_guid, message)
        end
      end

      describe '#send_desire_request' do
        let(:process_guid) { ProcessGuid.from_app(app) }
        let(:message) { { desire: 'message' } }

        before do
          allow(protocol).to receive(:desire_app_request).and_return(message)
          allow(nsync_client).to receive(:desire_app)
        end

        it 'sends a desire app request' do
          messenger.send_desire_request(app, default_health_check_timeout)

          expect(protocol).to have_received(:desire_app_request).with(app, default_health_check_timeout)
          expect(nsync_client).to have_received(:desire_app).with(process_guid, message)
        end
      end

      describe '#send_stop_staging_request' do
        let(:staging_guid) { StagingGuid.from_app(app) }

        before do
          allow(stager_client).to receive(:stop_staging)
        end

        it 'sends a stop_staging request to the stager' do
          messenger.send_stop_staging_request(app)

          expect(stager_client).to have_received(:stop_staging).with(staging_guid)
        end
      end

      describe '#send_stop_index_request' do
        let(:process_guid) { ProcessGuid.from_app(app) }
        let(:index) { 3 }

        before do
          allow(nsync_client).to receive(:stop_index)
        end

        it 'sends a stop index request' do
          messenger.send_stop_index_request(app, index)

          expect(nsync_client).to have_received(:stop_index).with(process_guid, index)
        end
      end

      describe '#send_stop_app_request' do
        let(:process_guid) { ProcessGuid.from_app(app) }

        before do
          allow(nsync_client).to receive(:stop_app)
        end

        it 'sends a stop app request' do
          messenger.send_stop_app_request(app)

          expect(nsync_client).to have_received(:stop_app).with(process_guid)
        end
      end
    end
  end
end
