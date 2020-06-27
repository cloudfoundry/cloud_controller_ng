require 'spec_helper'
require 'utils/workpool'

module VCAP::CloudController
  module Diego
    RSpec.describe ProcessesSync, job_context: :clock do
      subject { ProcessesSync.new(config: config, statsd_updater: statsd_updater) }
      let(:config) { instance_double(Config) }

      let(:bbs_apps_client) { instance_double(BbsAppsClient) }

      let(:scheduling_infos) { [] }
      let(:statsd_updater) { instance_double(VCAP::CloudController::Metrics::StatsdUpdater, update_synced_invalid_lrps: nil) }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_apps_client, bbs_apps_client)
        allow(bbs_apps_client).to receive(:fetch_scheduling_infos).and_return(scheduling_infos)
        allow(bbs_apps_client).to receive(:bump_freshness)
      end

      describe '#sync' do
        let(:workpool) { instance_double(WorkPool, submit: nil, exceptions: nil, drain: nil) }
        let(:fake_logger) { instance_double(Steno::Logger, debug: nil, info: nil, error: nil) }

        before do
          allow(Steno).to receive(:logger).and_return(fake_logger)
        end

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
            expect(bbs_apps_client).to have_received(:bump_freshness).once
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

          it 'updates stale lrps' do
            allow(bbs_apps_client).to receive(:update_app)
            subject.sync
            expect(bbs_apps_client).to have_received(:update_app).with(stale_process, stale_lrp_scheduling_info)
            expect(bbs_apps_client).to have_received(:bump_freshness).once
          end

          context 'when updating app fails' do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            before do
              allow(bbs_apps_client).to receive(:update_app).and_raise(error)
            end

            context 'when RunnerInvalidRequest is returned' do
              let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'bad request') }

              it 'bumps freshness' do
                expect { subject.sync }.not_to raise_error
                expect(bbs_apps_client).to have_received(:bump_freshness).once
              end
            end

            context 'when the app has been deleted' do
              let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'the requested resource could not be found') }
              let(:logger) { double(:logger, info: nil, error: nil) }

              before do
                allow(Steno).to receive(:logger).and_return(logger)
                allow(WorkPool).to receive(:new).and_return(workpool)
                allow(workpool).to receive(:submit)
                allow(workpool).to receive(:exceptions).and_return([error])
              end

              it 'bumps freshness, ignoring the error' do
                subject.sync
                expect(workpool).to have_received(:submit)
                expect(bbs_apps_client).to have_received(:bump_freshness)
                expect(logger).to_not have_received(:error)
                expect(logger).to have_received(:info).with(
                  'ignore-deleted-resource', error: error.name, error_message: error.message
                )
              end
            end

            context 'any other error' do
              let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'some error') }

              it 'does not bump freshness' do
                expect { subject.sync }.not_to raise_error
                expect(fake_logger).to have_received(:error).with(
                  'error-updating-lrp-state',
                    error: 'RunnerError',
                    error_message: 'Runner error: some error',
                    error_backtrace: anything
                )
                expect(bbs_apps_client).not_to have_received(:bump_freshness)
              end
            end
          end
        end

        context 'when diego does not contain the LRP' do
          let(:scheduling_infos) { [] }
          let!(:missing_process) { ProcessModel.make(:diego_runnable) }

          it 'creates missing lrps' do
            allow(bbs_apps_client).to receive(:desire_app).with(missing_process)
            subject.sync
            expect(bbs_apps_client).to have_received(:desire_app).with(missing_process)
            expect(bbs_apps_client).to have_received(:bump_freshness).once
          end

          context 'when desiring app fails' do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns

            before do
              allow(bbs_apps_client).to receive(:desire_app).and_raise(error)
            end

            context 'when RunnerInvalidRequest is returned' do
              let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'invalid thing') }

              it 'bumps freshness' do
                expect { subject.sync }.not_to raise_error
                expect(bbs_apps_client).to have_received(:bump_freshness).once
              end
            end

            context 'when any other error is returned' do
              let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'some error') }

              it 'does not bump freshness' do
                expect { subject.sync }.not_to raise_error
                expect(fake_logger).to have_received(:error).with(
                  'error-updating-lrp-state',
                    error: 'RunnerError',
                    error_message: 'Runner error: some error',
                    error_backtrace: anything
                )
                expect(bbs_apps_client).not_to have_received(:bump_freshness)
              end
            end
          end

          context 'when the missing process is a kpack-staged app' do
            let!(:missing_process) { ProcessModel.make(:kpack) }

            context 'with the diego_docker feature flag enabled' do
              before do
                VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true)
              end

              it 'creates missing lrps' do
                allow(bbs_apps_client).to receive(:desire_app).with(missing_process)
                subject.sync
                expect(bbs_apps_client).to have_received(:desire_app).with(missing_process)
                expect(bbs_apps_client).to have_received(:bump_freshness).once
              end
            end

            context 'with the diego_docker feature flag disabled' do
              before do
                VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false)
              end

              it 'creates missing lrps' do
                allow(bbs_apps_client).to receive(:desire_app).with(missing_process)
                subject.sync
                expect(bbs_apps_client).to have_received(:desire_app).with(missing_process)
                expect(bbs_apps_client).to have_received(:bump_freshness).once
              end
            end
          end
        end

        context 'when diego already contains the LRP' do
          let(:good_process) { ProcessModel.make(:diego_runnable) }
          let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'the requested resource already exists') }
          let(:indexed_by_thing) { instance_double(Hash) }
          let(:existing_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: "#{good_process.guid}-#{good_process.version}") }
          let(:logger) { double(:logger, info: nil, error: nil) }

          before do
            allow(existing_lrp).to receive(:nil?).and_return(true)
            allow(bbs_apps_client).to receive(:fetch_scheduling_infos).and_return(indexed_by_thing)
            allow(indexed_by_thing).to receive(:index_by).and_return({ existing_lrp.process_guid => existing_lrp })
            allow(Steno).to receive(:logger).and_return(logger)
            allow(WorkPool).to receive(:new).and_return(workpool)
            allow(workpool).to receive(:submit)
            allow(workpool).to receive(:exceptions).and_return([error])
          end

          it 'bumps freshness, ignoring the error' do
            subject.sync
            expect(workpool).to have_received(:submit)
            expect(bbs_apps_client).to have_received(:bump_freshness)
            expect(logger).to_not have_received(:error)
            expect(logger).to have_received(:info).with(
              'ignore-existing-resource', error: error.name, error_message: error.message
            )
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
            let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'some error') }

            before do
              allow(bbs_apps_client).to receive(:stop_app).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.not_to raise_error
              expect(fake_logger).to have_received(:error).with(
                'error-updating-lrp-state',
                  error: 'RunnerError',
                  error_message: 'Runner error: some error',
                  error_backtrace: anything
              )
              expect(bbs_apps_client).not_to have_received(:bump_freshness)
            end
          end
        end

        context 'when fetching from diego fails' do
          context "when there's a problem with the runner" do
            # bbs_apps_client will raise ApiErrors as of right now, we should think about factoring that out so that
            # the background job doesn't have to deal with API concerns
            let(:error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'some error') }
            before do
              allow(bbs_apps_client).to receive(:fetch_scheduling_infos).and_raise(error)
            end

            it 'does not bump freshness' do
              expect { subject.sync }.to raise_error(ProcessesSync::BBSFetchError, error.message)
              expect(bbs_apps_client).not_to have_received(:bump_freshness)
            end
          end

          context 'when an error occurs while updating an individual LRP' do
            let(:error) { VCAP::CloudController::Diego::LifecycleBundleUriGenerator::InvalidStack.new("no compiler defined for requested stack 'schmidlap'") }
            before do
              allow_any_instance_of(WorkPool).to receive(:exceptions).and_return([error])
            end

            it 'does not bump freshness' do
              subject.sync
              expect(fake_logger).to have_received(:error).with(
                'error-updating-lrp-state',
                  error: 'VCAP::CloudController::Diego::LifecycleBundleUriGenerator::InvalidStack',
                  error_message: "no compiler defined for requested stack 'schmidlap'",
                  error_backtrace: ''
              )
              expect(bbs_apps_client).not_to have_received(:bump_freshness)
            end
          end
        end

        context 'when a non-Diego error is raised outside of the workpool' do
          let(:error) { Sequel::Error.new('Generic Database Error') }

          before do
            allow(WorkPool).to receive(:new).and_return(workpool)
            allow(ProcessModel).to receive(:table_name).and_raise(error)
          end

          it 'does not bump freshness' do
            expect { subject.sync }.to raise_error(error)
            expect(bbs_apps_client).not_to have_received(:bump_freshness)
          end

          it 'drains the workpool threads to prevent thread leakage' do
            expect { subject.sync }.to raise_error(error)
            expect(workpool).to have_received(:drain)
          end
        end

        context 'when updating LRP state on diego fails multiple times with ignorable errors' do
          let(:scheduling_infos) { [] }
          let!(:missing_process1) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process2) { ProcessModel.make(:diego_runnable) }
          let(:ignorable_error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'invalid thing') }
          let(:fake_app_recipe) { instance_double(AppRecipeBuilder, build_app_lrp: double(:app_lrp_recipe)) }

          before do
            allow(AppRecipeBuilder).to receive(:new).and_return(fake_app_recipe)
            allow(bbs_apps_client).to receive(:desire_app).and_raise(ignorable_error)
          end

          it 'updates freshness' do
            subject.sync
            expect(bbs_apps_client).to have_received(:bump_freshness)
          end
        end

        context 'when updating LRP state on diego fails multiple times with some non-ignorable errors' do
          let(:scheduling_infos) { [] }
          let!(:missing_process1) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process2) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process3) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process4) { ProcessModel.make(:diego_runnable) }
          let(:ignorable_error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'invalid thing') }
          let(:non_ignorable_error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'some error') }
          let(:non_api_error) { StandardError.new('something went wrong') }
          let(:fake_app_recipe) { instance_double(AppRecipeBuilder, build_app_lrp: double(:app_lrp_recipe)) }

          before do
            allow(AppRecipeBuilder).to receive(:new).and_return(fake_app_recipe)

            calls = 0
            allow(bbs_apps_client).to receive(:desire_app) do
              raise ignorable_error if calls == 0
              raise non_ignorable_error if calls == 1

              raise non_api_error if calls == 2
            ensure
              calls += 1
            end
          end

          it 'does not update freshness' do
            expect { subject.sync }.not_to raise_error
            expect(fake_logger).to have_received(:error).with(
              'error-updating-lrp-state',
                error: 'RunnerError',
                error_message: 'Runner error: some error',
                error_backtrace: anything
            )
            expect(bbs_apps_client).not_to have_received(:bump_freshness)
          end

          it 'logs all exceptions' do
            expect { subject.sync }.not_to raise_error
            expect(fake_logger).to have_received(:info).with(
              'synced-invalid-desired-lrps',
              error: ignorable_error.name,
              error_message: ignorable_error.message
            )
            expect(fake_logger).to have_received(:error).with(
              'error-updating-lrp-state',
              error: non_ignorable_error.name,
              error_message: non_ignorable_error.message,
              error_backtrace: anything
            )
            expect(fake_logger).to have_received(:error).with(
              'error-updating-lrp-state',
              error: non_api_error.class.name,
              error_message: non_api_error.message,
              error_backtrace: anything
            )
          end

          it 'continues to attempt to update all necessary lrps' do
            subject.sync rescue nil
            expect(bbs_apps_client).to have_received(:desire_app).with(missing_process4)
          end
        end

        context 'when logging invalid-lrp-request count to statsd' do
          let!(:missing_process) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process2) { ProcessModel.make(:diego_runnable) }
          let!(:missing_process3) { ProcessModel.make(:diego_runnable) }
          let(:invalid_request_error) { CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', 'invalid thing') }
          let(:other_error) { CloudController::Errors::ApiError.new_from_details('RunnerError', 'bad error!') }

          before do
            allow(bbs_apps_client).to receive(:desire_app).with(missing_process).and_raise(invalid_request_error)
            allow(bbs_apps_client).to receive(:desire_app).with(missing_process2).and_raise(invalid_request_error)
            allow(bbs_apps_client).to receive(:desire_app).with(missing_process3).and_raise(other_error)
          end

          it 'updates invalid-request count even if another error is thrown' do
            expect { subject.sync }.not_to raise_error
            expect(bbs_apps_client).not_to have_received(:bump_freshness)
            expect(statsd_updater).to have_received(:update_synced_invalid_lrps).with(2)
          end
        end
      end
    end
  end
end
