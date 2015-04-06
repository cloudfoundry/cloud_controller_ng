require 'spec_helper'

module VCAP::CloudController
  module Dea
    describe Stager do
      let(:config) do
        instance_double(Config)
      end

      let(:message_bus) do
        instance_double(CfMessageBus::MessageBus, publish: nil)
      end

      let(:dea_pool) do
        instance_double(Dea::Pool)
      end

      let(:stager_pool) do
        instance_double(Dea::StagerPool)
      end

      let(:runners) do
        instance_double(Runners)
      end

      let(:runner) { double(:Runner) }

      subject(:stager) do
        Stager.new(thing_to_stage, config, message_bus, dea_pool, stager_pool, runners)
      end

      let(:stager_task) do
        double(AppStagerTask)
      end

      let(:reply_json_error) { nil }
      let(:reply_error_info) { nil }
      let(:detected_buildpack) { nil }
      let(:detected_start_command) { 'wait_for_godot' }
      let(:buildpack_key) { nil }
      let(:droplet_hash) { 'droplet-sha1' }
      let(:reply_json) do
        {
          'task_id' => 'task-id',
          'task_log' => 'task-log',
          'task_streaming_log_url' => nil,
          'detected_buildpack' => detected_buildpack,
          'buildpack_key' => buildpack_key,
          'procfile' => { 'web' => 'npm start' },
          'detected_start_command' => detected_start_command,
          'error' => reply_json_error,
          'error_info' => reply_error_info,
          'droplet_sha1' => droplet_hash,
        }
      end
      let(:staging_result) { StagingResponse.new(reply_json) }
      let(:staging_error) { nil }

      it_behaves_like 'a stager' do
        let(:thing_to_stage) { nil }
      end

      describe '#stage_app' do
        let(:thing_to_stage) { AppFactory.make }

        before do
          allow(AppStagerTask).to receive(:new).and_return(stager_task)
          allow(stager_task).to receive(:stage).and_yield('fake-staging-result').and_return('fake-stager-response')
          allow(runners).to receive(:runner_for_app).with(thing_to_stage).and_return(runner)
          allow(runner).to receive(:start).with('fake-staging-result')
        end

        it 'stages the app with a stager task' do
          stager.stage_app
          expect(stager_task).to have_received(:stage)
          expect(AppStagerTask).to have_received(:new).with(config,
                                                            message_bus,
                                                            thing_to_stage,
                                                            dea_pool,
                                                            stager_pool,
                                                            an_instance_of(CloudController::Blobstore::UrlGenerator))
        end

        it 'starts the app with the returned staging result' do
          stager.stage_app
          expect(runner).to have_received(:start).with('fake-staging-result')
        end

        it 'records the stager response on the app' do
          stager.stage_app
          expect(thing_to_stage.last_stager_response).to eq('fake-stager-response')
        end
      end

      describe '#stage_package' do
        let(:stager_task) { double(PackageStagerTask) }
        let(:staging_message) { double(:staging_message, buildpack_key: buildpack_key) }
        let(:blobstore_url_generator) { double(:blobstore_url_generator) }

        let(:stack) { 'lucid64' }
        let(:mem) { 1024 }
        let(:disk) { 1024 }
        let(:bp_guid) { 'bp-guid' }
        let(:buildpack_git_url) { 'buildpack-url' }
        let(:droplet_guid) { droplet.guid }
        let(:log_id) { droplet.guid }

        before do
          allow(PackageStagerTask).to receive(:new).and_return(stager_task)
          allow(PackageDEAStagingMessage).to receive(:new).
            with(
              package,
              droplet_guid,
              log_id,
              stack,
              mem,
              disk,
              anything,
              buildpack_git_url,
              config,
              environment_variables,
              an_instance_of(CloudController::Blobstore::UrlGenerator)).
            and_return(staging_message)
          allow(stager_task).to receive(:stage).and_yield(staging_result, staging_error).and_return('fake-stager-response')
        end

        let(:buildpack) { Buildpack.make(name: 'buildpack-name') }
        let(:buildpack_key) { buildpack.key }
        let(:environment_variables) { { 'VAR' => 'IABLE' } }

        let(:package) { PackageModel.make }
        let(:droplet) { DropletModel.make(environment_variables: environment_variables) }
        let(:thing_to_stage) { package }

        it 'stages the package with a stager task' do
          stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
          expect(stager_task).to have_received(:stage).with(staging_message)
          expect(PackageStagerTask).to have_received(:new).
            with(
              config,
              message_bus,
              dea_pool,
              stager_pool)
        end

        it 'updates the droplet to a STAGED state' do
          stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
          expect(droplet.refresh.state).to eq(DropletModel::STAGED_STATE)
        end

        it 'updates the droplet with the detected buildpack' do
          stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
          expect(droplet.refresh.buildpack_guid).to eq(buildpack.guid)
        end

        it 'updates the droplet with the detected start command' do
          stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
          expect(droplet.refresh.detected_start_command).to eq(detected_start_command)
        end

        it 'updates the droplet with the procfile' do
          stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
          expect(droplet.refresh.procfile).to eq(YAML.dump({
            'web' => 'npm start'
          }))
        end

        context 'when buildpack is not present' do
          let(:reply_json) do
            {
              'task_id' => 'task-id',
              'task_log' => 'task-log',
              'task_streaming_log_url' => nil,
              'detected_buildpack' => nil,
              'buildpack_key' => nil,
              'detected_start_command' => detected_start_command,
              'error' => reply_json_error,
              'error_info' => reply_error_info,
              'droplet_sha1' => droplet_hash,
            }
          end

          it 'does not try to update buildpack guid if not present' do
            stager.stage_package(droplet, stack, mem, disk, nil, buildpack_git_url)
            expect(droplet.refresh.buildpack_guid).to eq(nil)
          end
        end

        context 'when staging fails' do
          let(:failure_reason) { 'a staging error message' }
          let(:failure_type) { 'SomeType' }

          context 'because task.stage failed' do
            before do
              allow(stager_task).to receive(:stage).and_raise(PackageStagerTask::FailedToStage.new(failure_type, failure_reason))
            end

            it 'updates the droplet to a FAILED state' do
              expect(droplet.state).not_to eq(DropletModel::FAILED_STATE)

              begin
                stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
              rescue
              end

              expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
            end

            it 'stores the failure reason on the droplet' do
              begin
                stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)
              rescue
              end

              expect(droplet.reload.failure_reason).to match(/#{failure_type}.*#{failure_reason}/)
            end

            it 'raises an ApiError' do
              expect { stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url) }.
                to raise_error(VCAP::Errors::ApiError, /a staging error message/)
            end
          end

          context 'because there was an error passed to the callback' do
            let(:staging_error) { PackageStagerTask::FailedToStage.new(failure_type, failure_reason) }

            it 'updates the droplet to a FAILED state' do
              expect(droplet.state).not_to eq(DropletModel::FAILED_STATE)

              stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)

              expect(droplet.reload.state).to eq(DropletModel::FAILED_STATE)
            end

            it 'stores the failure reason on the droplet' do
              stager.stage_package(droplet, stack, mem, disk, bp_guid, buildpack_git_url)

              expect(droplet.reload.failure_reason).to match(/#{failure_type}.*#{failure_reason}/)
            end
          end
        end
      end
    end
  end
end
