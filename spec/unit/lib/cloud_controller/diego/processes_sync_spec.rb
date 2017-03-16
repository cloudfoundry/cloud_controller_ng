require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe ProcessesSync do
      subject { ProcessesSync.new(config) }
      let(:config) { double(:config) }

      let(:bbs_apps_client) { instance_double(BbsAppsClient) }

      let!(:missing_process_unstarted) { ProcessModel.make(:diego_runnable, state: 'STOPPED') }
      let!(:missing_process_no_droplet) { ProcessModel.make(:process) }
      let!(:missing_process_dea) { ProcessModel.make(:dea_runnable) }

      let(:scheduling_infos) { [] }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
        allow(bbs_apps_client).to receive(:fetch_scheduling_infos).and_return(scheduling_infos)
        allow(bbs_apps_client).to receive(:bump_freshness)
      end

      describe '#sync' do
        it 'bumps freshness' do
          subject.sync
          expect(bbs_apps_client).to have_received(:bump_freshness).once
        end

        context 'when bbs and CC are in sync' do
          let(:scheduling_infos) { [good_lrp_scheduling_info] }
          let(:good_lrp_scheduling_info) do
            ::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new(
              desired_lrp_key: ::Diego::Bbs::Models::DesiredLRPKey.new({
                process_guid: ProcessGuid.from_process(good_process),
              }),
              annotation:      good_process.updated_at.to_f.to_s,
            )
          end
          let(:good_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: 'good-lrp') }
          let!(:good_process) { ProcessModel.make(:diego_runnable) }

          it 'does not touch lrps that are up to date and correct' do
            allow(bbs_apps_client).to receive(:desire_app)
            allow(bbs_apps_client).to receive(:update_app)
            allow(bbs_apps_client).to receive(:stop_app)

            subject.sync

            expect(bbs_apps_client).not_to have_received(:desire_app)
            expect(bbs_apps_client).not_to have_received(:update_app)
            expect(bbs_apps_client).not_to have_received(:stop_app)
          end
        end

        context 'when a diego LRP is stale' do
          let(:scheduling_infos) { [stale_lrp_scheduling_info] }
          let(:stale_lrp_scheduling_info) do
            ::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new(
              desired_lrp_key: ::Diego::Bbs::Models::DesiredLRPKey.new({
                process_guid: ProcessGuid.from_process(stale_process),
              }),
              annotation:      'outdated',
            )
          end
          let(:stale_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: 'stale-lrp') }
          let(:stale_lrp_update) do
            ::Diego::Bbs::Models::DesiredLRPUpdate.new(
              instances:  stale_process.instances,
              annotation: stale_process.updated_at.to_f.to_s,
              routes:     ::Diego::Bbs::Models::ProtoRoutes.new(routes: [])
            )
          end
          let!(:stale_process) { ProcessModel.make(:diego_runnable) }

          before do
            stale_lrp_recipe_builder = instance_double(AppRecipeBuilder)
            allow(AppRecipeBuilder).to receive(:new).with(config: config, process: stale_process).and_return(stale_lrp_recipe_builder)
            allow(stale_lrp_recipe_builder).to receive(:build_app_lrp_update).with(stale_lrp_scheduling_info).and_return(stale_lrp_update)
          end

          it 'updates stale lrps' do
            allow(bbs_apps_client).to receive(:update_app)
            subject.sync
            expect(bbs_apps_client).to have_received(:update_app).with(ProcessGuid.from_process(stale_process), stale_lrp_update)
          end

          context 'when updating app fails' do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new }

            before do
              allow(bbs_apps_client).to receive(:update_app).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(ProcessesSync::BBSFetchError, error.message)
              expect(bbs_apps_client).not_to receive(:bump_freshness)
            end
          end
        end

        context 'when diego does not contain the LRP' do
          let!(:missing_process) { ProcessModel.make(:diego_runnable) }
          let(:missing_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: 'missing-lrp') }

          before do
            missing_lrp_recipe_builder = instance_double(AppRecipeBuilder)
            allow(AppRecipeBuilder).to receive(:new).with(config: config, process: missing_process).and_return(missing_lrp_recipe_builder)
            allow(missing_lrp_recipe_builder).to receive(:build_app_lrp).and_return(missing_lrp)
          end

          it 'creates missing lrps' do
            allow(bbs_apps_client).to receive(:desire_app).with(missing_lrp)
            subject.sync
            expect(bbs_apps_client).to have_received(:desire_app).with(missing_lrp)
          end

          context 'when desiring app fails' do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new }

            before do
              allow(bbs_apps_client).to receive(:desire_app).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(ProcessesSync::BBSFetchError, error.message)
              expect(bbs_apps_client).not_to receive(:bump_freshness)
            end
          end
        end

        context 'when CC does not know about a LRP' do
          let(:scheduling_infos) { [deleted_lrp_scheduling_info] }
          let(:deleted_lrp_scheduling_info) do
            ::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new(
              desired_lrp_key: ::Diego::Bbs::Models::DesiredLRPKey.new({
                process_guid: 'deleted',
              }),
            )
          end
          it 'deletes deleted lrps' do
            allow(bbs_apps_client).to receive(:stop_app)
            subject.sync
            expect(bbs_apps_client).to have_received(:stop_app).with('deleted')
          end

          context 'when stopping app fails' do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new }

            before do
              allow(bbs_apps_client).to receive(:stop_app).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(ProcessesSync::BBSFetchError, error.message)
              expect(bbs_apps_client).not_to receive(:bump_freshness)
            end
          end
        end

        context 'when fetching from diego fails' do
          # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
          # the background job doesn't have to deal with API concerns
          let(:error) { CloudController::Errors::ApiError.new }

          before do
            allow(bbs_apps_client).to receive(:fetch_scheduling_infos).and_raise(error)
          end

          it 'does not bump freshness' do
            expect { subject.sync }.to raise_error(ProcessesSync::BBSFetchError, error.message)
            expect(bbs_apps_client).not_to receive(:bump_freshness)
          end
        end

        context 'correctly syncs in batches' do
          let!(:scheduling_infos) { [] }

          before do
            stub_const('VCAP::CloudController::Diego::ProcessesSync::BATCH_SIZE', 5)
            (ProcessesSync::BATCH_SIZE + 1).times do |_|
              process = ProcessModel.make(:diego_runnable)

              lrp_info = ::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new(
                desired_lrp_key: ::Diego::Bbs::Models::DesiredLRPKey.new(
                  process_guid: ProcessGuid.from_process(process),
                ),
                annotation:      process.updated_at.to_f.to_s,
              )
              scheduling_infos << lrp_info
            end
          end

          it 'does nothing to the task' do
            allow(bbs_apps_client).to receive(:desire_app)
            allow(bbs_apps_client).to receive(:update_app)
            allow(bbs_apps_client).to receive(:stop_app)

            subject.sync

            expect(bbs_apps_client).not_to have_received(:desire_app)
            expect(bbs_apps_client).not_to have_received(:update_app)
            expect(bbs_apps_client).not_to have_received(:stop_app)
          end
        end
      end
    end
  end
end
