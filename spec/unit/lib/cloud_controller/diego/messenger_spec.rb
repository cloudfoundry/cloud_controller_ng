require 'spec_helper'
require 'cloud_controller/diego/bbs_stager_client'

module VCAP::CloudController
  module Diego
    RSpec.describe Messenger do
      subject(:messenger) { Messenger.new(statsd_updater) }
      let(:statsd_updater) { instance_double(VCAP::CloudController::Metrics::StatsdUpdater) }

      let(:stager_client) { instance_double(StagerClient) }
      let(:nsync_client) { instance_double(NsyncClient) }
      let(:bbs_stager_client) { instance_double(BbsStagerClient) }
      let(:config) { TestConfig.config_instance }
      let(:protocol) { instance_double(Diego::Protocol) }
      let(:task_recipe_builder) { instance_double(Diego::TaskRecipeBuilder) }
      let(:config_overrides) { {} }

      before do
        TestConfig.override(config_overrides)
        CloudController::DependencyLocator.instance.register(:bbs_stager_client, bbs_stager_client)
        CloudController::DependencyLocator.instance.register(:stager_client, stager_client)
        CloudController::DependencyLocator.instance.register(:nsync_client, nsync_client)
        allow(Diego::Protocol).to receive(:new).and_return(protocol)
        allow(Diego::TaskRecipeBuilder).to receive(:new).and_return(task_recipe_builder)
      end

      describe '#send_stage_request' do
        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(package: package) }
        let(:staging_guid) { droplet.guid }
        let(:message) { { staging: 'message' } }
        let(:staging_details) do
          VCAP::CloudController::Diego::StagingDetails.new.tap do |sd|
            sd.package = package
            sd.staging_guid = staging_guid
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
          let(:config_overrides) { { diego: { temporary_local_staging: true } } }

          before do
            staging_details.lifecycle = instance_double(BuildpackLifecycle, type: Lifecycles::BUILDPACK)
            allow(task_recipe_builder).to receive(:build_staging_task).and_return(message)
            allow(bbs_stager_client).to receive(:stage)
            allow(statsd_updater).to receive(:start_staging_request_received)
          end

          it 'emits the `cc.staging.requested` metric' do
            expect(statsd_updater).to receive(:start_staging_request_received)
            messenger.send_stage_request(config, staging_details)
          end

          it 'sends the staging message to the bbs' do
            messenger.send_stage_request(config, staging_details)

            expect(task_recipe_builder).to have_received(:build_staging_task).with(config, staging_details)
            expect(bbs_stager_client).to have_received(:stage).with(staging_guid, message)
          end
        end
      end

      describe '#send_desire_request' do
        let(:process) { ProcessModel.new }
        let(:default_health_check_timeout) { 99 }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:message) { { desire: 'message' } }
        let(:config) { Config.new({ default_health_check_timeout: default_health_check_timeout }) }

        before do
          allow(protocol).to receive(:desire_app_request).and_return(message)
          allow(nsync_client).to receive(:desire_app)
        end

        it 'sends a desire app request' do
          messenger.send_desire_request(process, config)

          expect(protocol).to have_received(:desire_app_request).with(process, default_health_check_timeout)
          expect(nsync_client).to have_received(:desire_app).with(process_guid, message)
        end

        context 'when configured to start an app directly to diego' do
          let(:bbs_apps_client) { instance_double(BbsAppsClient, desire_app: nil) }
          let(:app_recipe_builder) { instance_double(Diego::AppRecipeBuilder, build_app_lrp: build_lrp) }
          let(:build_lrp) { instance_double(::Diego::Bbs::Models::DesiredLRP) }
          let(:config_overrides) { { diego: { temporary_local_apps: true } } }

          before do
            CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
            allow(Diego::AppRecipeBuilder).to receive(:new).with(config: config, process: process).and_return(app_recipe_builder)
          end

          it 'attempts to create or update the app by delegating to the desire app handler' do
            allow(DesireAppHandler).to receive(:create_or_update_app)
            messenger.send_desire_request(process, config)

            expect(DesireAppHandler).to have_received(:create_or_update_app).with(process_guid, app_recipe_builder, bbs_apps_client)
          end
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
        let(:process) { ProcessModel.new }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:index) { 3 }

        before do
          allow(nsync_client).to receive(:stop_index)
        end

        it 'sends a stop index request' do
          messenger.send_stop_index_request(process, index)

          expect(nsync_client).to have_received(:stop_index).with(process_guid, index)
        end

        context 'when configured to stop an index directly to diego' do
          let(:bbs_apps_client) { instance_double(BbsAppsClient, stop_index: nil) }
          let(:config_overrides) { { diego: { temporary_local_apps: true } } }

          before do
            CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
          end

          it 'sends a stop index request to the bbs' do
            messenger.send_stop_index_request(process, index)

            expect(bbs_apps_client).to have_received(:stop_index).with(process_guid, index)
          end
        end
      end

      describe '#send_stop_app_request' do
        let(:process) { ProcessModel.new }
        let(:process_guid) { ProcessGuid.from_process(process) }

        before do
          allow(nsync_client).to receive(:stop_app)
        end

        it 'sends a stop app request' do
          messenger.send_stop_app_request(process)

          expect(nsync_client).to have_received(:stop_app).with(process_guid)
        end

        context 'when configured to stop an app directly to diego' do
          let(:bbs_apps_client) { instance_double(BbsAppsClient, stop_app: nil) }
          let(:config_overrides) { { diego: { temporary_local_apps: true } } }

          before do
            CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
          end

          it 'sends a stop app request to the bbs' do
            messenger.send_stop_app_request(process)

            expect(bbs_apps_client).to have_received(:stop_app).with(process_guid)
          end
        end
      end
    end
  end
end
