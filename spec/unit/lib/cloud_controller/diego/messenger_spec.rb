require 'spec_helper'
require 'cloud_controller/diego/bbs_stager_client'

module VCAP::CloudController
  module Diego
    RSpec.describe Messenger do
      subject(:messenger) { Messenger.new }

      let(:stager_client) { instance_double(StagerClient) }
      let(:nsync_client) { instance_double(NsyncClient) }
      let(:bbs_stager_client) { instance_double(BbsStagerClient) }
      let(:config) { TestConfig.config }
      let(:protocol) { instance_double(Diego::Protocol) }
      let(:recipe_builder) { instance_double(Diego::RecipeBuilder) }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_stager_client, bbs_stager_client)
        CloudController::DependencyLocator.instance.register(:stager_client, stager_client)
        CloudController::DependencyLocator.instance.register(:nsync_client, nsync_client)
        allow(Diego::Protocol).to receive(:new).and_return(protocol)
        allow(Diego::RecipeBuilder).to receive(:new).and_return(recipe_builder)
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

        context 'when staging local is configured and lifecycle is buildpack' do
          before do
            TestConfig.override(diego: { temporary_local_staging: true })
            staging_details.lifecycle = instance_double(BuildpackLifecycle, type: Lifecycles::BUILDPACK)
            allow(recipe_builder).to receive(:build_staging_task).and_return(message)
            allow(bbs_stager_client).to receive(:stage)
          end

          it 'sends the staging message to the bbs' do
            messenger.send_stage_request(config, staging_details)

            expect(recipe_builder).to have_received(:build_staging_task).with(config, staging_details)
            expect(bbs_stager_client).to have_received(:stage).with(staging_guid, message)
          end
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
