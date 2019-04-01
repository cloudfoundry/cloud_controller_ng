require 'spec_helper'
require 'cloud_controller/diego/bbs_stager_client'

module VCAP::CloudController
  module Diego
    RSpec.describe Messenger do
      subject(:messenger) { Messenger.new(statsd_updater) }
      let(:statsd_updater) { instance_double(VCAP::CloudController::Metrics::StatsdUpdater) }

      let(:bbs_stager_client) { instance_double(BbsStagerClient) }
      let(:config) { TestConfig.config_instance }
      let(:task_recipe_builder) { instance_double(Diego::TaskRecipeBuilder) }
      let(:bbs_apps_client) { instance_double(BbsAppsClient, desire_app: nil, get_app: nil) }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
        CloudController::DependencyLocator.instance.register(:bbs_stager_client, bbs_stager_client)
        allow(Diego::TaskRecipeBuilder).to receive(:new).and_return(task_recipe_builder)
      end

      describe '#send_stage_request' do
        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(package: package) }
        let(:staging_guid) { droplet.guid }
        let(:staging_details) do
          VCAP::CloudController::Diego::StagingDetails.new.tap do |sd|
            sd.package = package
            sd.staging_guid = staging_guid
          end
        end

        before do
          staging_details.lifecycle = instance_double(BuildpackLifecycle, type: Lifecycles::BUILDPACK)
          allow(bbs_stager_client).to receive(:stage)
          allow(statsd_updater).to receive(:start_staging_request_received)
        end

        it 'emits the `cc.staging.requested` metric' do
          expect(statsd_updater).to receive(:start_staging_request_received)
          messenger.send_stage_request(config, staging_details)
        end

        it 'sends the staging message to the bbs' do
          messenger.send_stage_request(config, staging_details)

          expect(bbs_stager_client).to have_received(:stage).with(staging_guid, staging_details)
        end
      end

      describe '#send_desire_request' do
        let(:process) { ProcessModel.new }
        let(:default_health_check_timeout) { 99 }
        let(:config) { Config.new({ default_health_check_timeout: default_health_check_timeout }) }

        it 'attempts to create or update the app by delegating to the desire app handler' do
          allow(DesireAppHandler).to receive(:create_or_update_app)
          messenger.send_desire_request(process)

          expect(DesireAppHandler).to have_received(:create_or_update_app).with(process, bbs_apps_client)
        end
      end

      describe '#send_stop_staging_request' do
        let(:staging_guid) { 'whatever' }

        before do
          allow(bbs_stager_client).to receive(:stop_staging)
        end

        it 'sends a stop_staging request to the stager' do
          messenger.send_stop_staging_request(staging_guid)

          expect(bbs_stager_client).to have_received(:stop_staging).with(staging_guid)
        end
      end

      describe '#send_stop_index_request' do
        let(:process) { ProcessModel.new }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:index) { 3 }
        let(:bbs_apps_client) { instance_double(BbsAppsClient, stop_index: nil) }

        it 'sends a stop index request to the bbs' do
          messenger.send_stop_index_request(process, index)

          expect(bbs_apps_client).to have_received(:stop_index).with(process_guid, index)
        end
      end

      describe '#send_stop_app_request' do
        let(:process) { ProcessModel.new }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:bbs_apps_client) { instance_double(BbsAppsClient, stop_app: nil) }

        it 'sends a stop app request to the bbs' do
          messenger.send_stop_app_request(process)

          expect(bbs_apps_client).to have_received(:stop_app).with(process_guid)
        end
      end
    end
  end
end
