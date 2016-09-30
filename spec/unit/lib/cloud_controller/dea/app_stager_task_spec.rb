require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Dea::AppStagerTask do
    subject!(:staging_task) { Dea::AppStagerTask.new(config_hash, message_bus, droplet, dea_pool, blobstore_url_generator) }

    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:dea_pool) { instance_double(Dea::Pool, reserve_app_memory: nil) }
    let(:config_hash) { { staging: { timeout_in_seconds: 360 } } }
    let(:droplet_sha1) { nil }
    let(:app) do
      AppFactory.make(
        type:       'web',
        state:      'STARTED',
        instances:  1,
        disk_quota: 1024
      )
    end
    let(:package) { PackageModel.make(app: app.app, package_hash: 'some-hash', state: PackageModel::READY_STATE) }
    let(:droplet) { DropletModel.make(app: app.app, package: package) }

    let(:dea_advertisement) { Dea::NatsMessages::DeaAdvertisement.new({ 'id' => 'my_stager' }, nil) }
    let(:stager_id) { dea_advertisement.dea_id }

    let(:blobstore_url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }

    let(:options) { {} }

    let(:first_reply_json_error) { nil }
    let(:task_streaming_log_url) { 'task-streaming-log-url' }

    let(:first_reply_json) do
      {
        'task_id'                => 'task-id',
        'task_log'               => 'task-log',
        'task_streaming_log_url' => task_streaming_log_url,
        'detected_buildpack'     => nil,
        'detected_start_command' => nil,
        'buildpack_key'          => nil,
        'error'                  => first_reply_json_error,
        'droplet_sha1'           => nil
      }
    end

    let(:reply_json_error) { nil }
    let(:reply_error_info) { nil }
    let(:detected_buildpack) { nil }
    let(:detected_start_command) { 'wait_for_godot' }
    let(:buildpack_key) { nil }

    let(:reply_json) do
      {
        'task_id'                => 'task-id',
        'task_log'               => 'task-log',
        'task_streaming_log_url' => nil,
        'detected_buildpack'     => detected_buildpack,
        'buildpack_key'          => buildpack_key,
        'detected_start_command' => detected_start_command,
        'error'                  => reply_json_error,
        'error_info'             => reply_error_info,
        'droplet_sha1'           => 'droplet-sha1',
        'execution_metadata'     => 'i got your data homey'
      }
    end

    def stage(&blk)
      stub_schedule_sync do
        @before_staging_completion.call if @before_staging_completion
        message_bus.respond_to_request("staging.#{stager_id}.start", first_reply_json)
      end

      response = staging_task.stage(&blk)
      response
    end

    before do
      expect(app.staged?).to be false

      allow(dea_pool).to receive(:find_stager).with(app.stack.name, 1024, anything).and_return(dea_advertisement)

      allow(EM).to receive(:add_timer)
      allow(EM).to receive(:defer).and_yield
      allow(EM).to receive(:schedule_sync)
    end

    context 'when http is enabled' do
      context 'when the dea supports http' do
        let(:dea_advertisement) { Dea::NatsMessages::DeaAdvertisement.new({ 'id' => 'my_stager', 'url' => 'https://adea.dea' }, nil) }
        let(:staging_message) { 'message' }
        before do
          allow(Dea::Client).to receive(:enabled?).and_return(true)
          allow(staging_task).to receive(:staging_request).and_return(staging_message)
        end

        it 'uses http' do
          expect(message_bus).to receive(:publish).with('staging.stop', { app_id: app.guid })
          expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, app.memory)
          expect(Dea::Client).to receive(:stage).with(dea_advertisement.url, staging_message).and_return(202)
          expect(message_bus).not_to receive(:publish).with('staging.my_stager.start', staging_task.staging_request)

          staging_task.stage

          expect(app.reload.staging_task_id).to eq(staging_task.task_id)
          expect(app.package_state).to eq('PENDING')
        end

        context 'when staging is not supported' do
          it 'failsover to NATs' do
            expect(message_bus).to receive(:publish).with('staging.stop', { app_id: app.guid })
            expect(Dea::Client).to receive(:stage).with(dea_advertisement.url, staging_message).and_return(404)
            expect(message_bus).to receive(:publish).with('staging.my_stager.start', staging_task.staging_request)

            stage
          end
        end

        context 'when an error occurs' do
          let(:logger) { double(Steno) }

          before do
            allow(staging_task).to receive(:logger).and_return(logger)
            allow(logger).to receive(:info)
          end

          it 'marks app as failed and raises an error' do
            allow(Dea::Client).to receive(:stage).and_raise 'failure'

            expect(logger).to receive(:error).with(/failure/)
            expect { staging_task.stage }.to raise_error 'failure'
            expect(app.reload.staging_failed_reason).to eq('StagingError')
          end

          context 'when the dea chosen returns a 503' do
            it 'retries to stage' do
              expect(Dea::Client).to receive(:stage).and_return(503, 202)
              expect(staging_task).to receive(:stage).twice.and_call_original

              staging_task.stage
            end
          end
        end
      end

      context 'when the dea does not support http' do
        it 'uses nats' do
          expect(message_bus).to receive(:publish).with('staging.stop', { app_id: app.guid })
          expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, app.memory)
          expect(staging_task).not_to receive(:stage_with_http)

          staging_task.stage

          expect(app.reload.staging_task_id).to eq(staging_task.task_id)
          expect(app.package_state).to eq('PENDING')
        end
      end
    end

    describe '#handle_http_response' do
      let(:response) { reply_json.merge({ 'dea_id' => dea_advertisement.dea_id }) }

      before do
        allow(Dea::Client).to receive(:enabled?).and_return(true)
        staging_task.stage
      end

      context 'when the DEA sends a staging success response' do
        let(:detected_buildpack) { 'buildpack detect output' }

        context 'when no other staging has happened' do
          before do
            allow(dea_pool).to receive(:mark_app_started)
          end

          it 'marks the app as staged' do
            expect { staging_task.handle_http_response(response) }.to change { app.refresh.staged? }.to(true)
          end

          it 'saves the detected buildpack' do
            expect { staging_task.handle_http_response(response) }.to change { app.refresh.detected_buildpack }.from(nil)
          end

          context 'and the droplet has been uploaded' do
            before do
              droplet.update(state: DropletModel::STAGED_STATE, droplet_hash: 'abc')
            end

            it 'saves the detected start command' do
              expect { staging_task.handle_http_response(response) }.to change {
                app.refresh.current_droplet
                app.detected_start_command
              }.from('').to('wait_for_godot')
            end
          end

          context 'when the droplet somehow has not been uploaded (defensive)' do
            it 'does not change the start command' do
              expect { staging_task.handle_http_response(response) }.not_to change {
                app.detected_start_command
              }.from('')
            end
          end

          context 'when detected_start_command is not returned' do
            let(:response) do
              {
                'task_id'                => 'task-id',
                'task_log'               => 'task-log',
                'task_streaming_log_url' => nil,
                'detected_buildpack'     => detected_buildpack,
                'buildpack_key'          => buildpack_key,
                'error'                  => reply_json_error,
                'error_info'             => reply_error_info,
                'droplet_sha1'           => 'droplet-sha1'
              }
            end

            it 'does not change the detected start command' do
              expect { staging_task.handle_http_response(response) }.not_to change {
                app.refresh.current_droplet
                app.detected_start_command
              }.from('')
            end
          end

          context 'when an admin buildpack is used' do
            let(:admin_buildpack) { Buildpack.make(name: 'buildpack-name') }
            let(:buildpack_key) { admin_buildpack.key }

            it 'saves the detected buildpack guid' do
              expect { staging_task.handle_http_response(response) }.to change { app.refresh.detected_buildpack_guid }.from(nil)
            end
          end

          it 'does not clobber other attributes that changed between staging' do
            # fake out the app refresh as the race happens after it
            allow(app).to receive(:refresh)

            other_app_ref         = App.find(guid: app.guid)
            other_app_ref.command = 'some other command'
            other_app_ref.save

            expect { staging_task.handle_http_response(response) }.to_not change {
              other_app_ref.refresh.command
            }
          end

          it 'marks app started in dea pool' do
            expect(dea_pool).to receive(:mark_app_started).with({ dea_id: dea_advertisement.dea_id, app_id: app.guid })
            staging_task.handle_http_response(response)
          end

          context 'when callback is not nil' do
            before do
              @callback_options = nil
            end

            it 'calls provided callback' do
              staging_task.handle_http_response(response) { |options| @callback_options = options }
              expect(@callback_options[:started_instances]).to equal(1)
            end
          end
        end

        context 'when staging was already marked as failed' do
          let(:droplet) { DropletModel.make(app: app.app, package: package, state: DropletModel::FAILED_STATE) }

          it 'does not mark the app as staged' do
            expect {
              ignore_staging_error { staging_task.handle_http_response(response) }
            }.not_to change { app.refresh.staged? }
          end

          it 'raises a StagingError' do
            expect {
              staging_task.handle_http_response(response)
            }.to raise_error(
              CloudController::Errors::ApiError,
              /staging had already been marked as failed, this could mean that staging took too long/
            )
          end
        end
      end

      context 'when the response is empty' do
        let(:response) { nil }
        let(:logger) { double(Steno).as_null_object }

        before do
          allow(staging_task).to receive(:logger).and_return(logger)
        end

        it 'logs StagingError' do
          expect(logger).to receive(:error).with(/Encountered error on stager with id #{stager_id}/)
          ignore_staging_error { staging_task.handle_http_response(response) }
        end

        it 'keeps the app as not staged' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to_not change { app.staged? }.from(false)
        end

        context 'when it has a callback' do
          before do
            @callback_called = false
            staging_task.stage { @callback_called = true }
            expect(@callback_called).to be false
          end
          it 'does not call provided callback (not yet)' do
            ignore_staging_error { staging_task.handle_http_response(response) }
            expect(@callback_called).to be false
          end
        end

        it 'marks the app as having failed to stage' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to change { app.reload.staging_failed? }.to(true)
        end

        it 'leaves the app with a generic staging failed reason' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to change { app.reload.staging_failed_reason }.to('StagerError')
        end
      end

      context 'when app staging returned an error response' do
        let(:reply_json_error) { 'staging failed' }
        let(:logger) { double(Steno).as_null_object }

        before do
          allow(staging_task).to receive(:logger).and_return(logger)
        end

        it 'logs StagingError' do
          expect(logger).to receive(:error) do |msg|
            expect(msg).to match(/Encountered error on stager with id #{stager_id}/)
          end

          ignore_staging_error { staging_task.handle_http_response(response) }
        end

        it 'keeps the app as not staged' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to_not change { app.staged? }.from(false)
        end

        it 'does not save the detected buildpack' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to_not change { app.detected_buildpack }.from(nil)
        end

        it 'does not save the detected buildpack guid' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to_not change { app.detected_buildpack_guid }.from(nil)
        end

        it 'does not save the detected start command' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to_not change { app.detected_start_command }.from('')
        end

        context 'when it has a callback' do
          before do
            @callback_called = false
            staging_task.stage { @callback_called = true }
            expect(@callback_called).to be false
          end
          it 'does not call provided callback (not yet)' do
            ignore_staging_error { staging_task.handle_http_response(response) }
            expect(@callback_called).to be false
          end
        end

        it 'marks the app as having failed to stage' do
          expect {
            ignore_staging_error { staging_task.handle_http_response(response) }
          }.to change { app.reload.staging_failed? }.to(true)
        end

        context 'when a staging error is present' do
          let(:reply_error_info) { { 'type' => 'NoAppDetectedError', 'message' => 'uh oh' } }

          it 'sets the staging failed reason to the specified value' do
            expect {
              ignore_staging_error { staging_task.handle_http_response(response) }
            }.to change { app.reload.staging_failed_reason }.to('NoAppDetectedError')
          end
        end

        context 'when a staging error is not present' do
          let(:reply_error_info) { nil }

          it 'sets staging failed reason to StagerError' do
            expect {
              ignore_staging_error { staging_task.handle_http_response(response) }
            }.to change { app.reload.staging_failed_reason }.to('StagerError')
          end
        end
      end
    end

    context 'when no stager can be found' do
      let(:dea_advertisement) { nil }

      it 'should raise an error' do
        expect {
          staging_task.stage
        }.to raise_error(CloudController::Errors::ApiError, /no available stagers/)
      end
    end

    context 'when a stager can be found' do
      it 'should stop other staging tasks' do
        expect(message_bus).to receive(:publish).with('staging.stop', hash_including({ app_id: app.guid }))
        staging_task.stage
      end
    end

    describe 'staging memory requirements' do
      context 'when the app memory requirement exceeds the staging memory requirement (1024)' do
        let(:app) do
          AppFactory.make(
            type:       'web',
            state:      'STARTED',
            instances:  1,
            memory: 1025
          )
        end

        it 'should request a stager with the app memory requirement' do
          expect(dea_pool).to receive(:find_stager).with(app.stack.name, 1025, anything).and_return(dea_advertisement)
          staging_task.stage
        end
      end

      context 'when the app memory requirement is less than the staging memory requirement' do
        it 'requests the staging memory requirement' do
          config_hash[:staging][:minimum_staging_memory_mb] = 2048
          expect(dea_pool).to receive(:find_stager).with(app.stack.name, 2048, anything).and_return(dea_advertisement)
          staging_task.stage
        end
      end
    end

    describe 'staging disk requirements' do
      let(:app) do
        AppFactory.make(
          type:       'web',
          state:      'STARTED',
          instances:  1,
          disk_quota: disk_quota
        )
      end

      context 'when the app disk requirement is less than the staging disk requirement' do
        let(:disk_quota) { 12 }

        it 'should request a stager with enough disk' do
          config_hash[:staging][:minimum_staging_disk_mb] = 1025
          expect(dea_pool).to receive(:find_stager).with(app.stack.name, anything, 1025).and_return(dea_advertisement)
          staging_task.stage
        end
      end

      context 'when the app disk requirement is less than the default (4096) staging disk requirement, and it wasnt overridden' do
        let(:disk_quota) { 123 }

        it 'should request a stager with enough disk' do
          config_hash[:staging][:minimum_staging_disk_mb] = nil
          expect(dea_pool).to receive(:find_stager).with(app.stack.name, anything, 4096).and_return(dea_advertisement)
          staging_task.stage
        end
      end

      context 'when the app disk requirement exceeds the staging disk requirement' do
        let(:disk_quota) { 123 }

        it 'should request a stager with enough disk' do
          config_hash[:staging][:minimum_staging_disk_mb] = 122
          expect(dea_pool).to receive(:find_stager).with(app.stack.name, anything, 123).and_return(dea_advertisement)
          staging_task.stage
        end
      end
    end

    describe 'staging' do
      describe 'receiving the first response from the stager (the staging setup completion message)' do
        context 'it sets up the app' do
          it 'sets the app package state to pending before it tries to stage' do
            stage

            expect(app.package_state).to eq('PENDING')
          end
        end

        context 'when staging setup succeeds' do
          it 'returns streaming log url and rest will happen asynchronously' do
            expect(stage.streaming_log_url).to eq('task-streaming-log-url')
          end

          it 'leaves the app as not having been staged' do
            stage
            expect(app).to be_pending
          end

          context 'when there are available stagers' do
            it 'stops other staging tasks and starts a new one' do
              expect(message_bus).to receive(:publish).with('staging.stop', anything)
              expect(message_bus).to receive(:publish).with('staging.my_stager.start', staging_task.staging_request)

              stage
            end

            it 'saves staging task id as the droplet guid' do
              stage
              expect(app.reload.staging_task_id).to eq(droplet.guid)
            end
          end
          it 'keeps the app as not staged' do
            expect { stage }.to_not change { app.staged? }.from(false)
          end

          it 'does not save the detected start command' do
            expect { stage }.to_not change { app.detected_start_command }.from('')
          end

          it 'does not save the detected buildpack' do
            expect { stage }.to_not change { app.detected_buildpack }.from(nil)
          end

          it 'does not save the detected buildpack guid' do
            expect { stage }.to_not change { app.detected_buildpack_guid }.from(nil)
          end

          it 'does not call provided callback (not yet)' do
            callback_called = false
            stage { callback_called = true }
            expect(callback_called).to be false
          end

          it 'builds the staging message before scheduling the promise' do
            expect(staging_task).to receive(:staging_request).ordered
            expect(EM).to receive(:schedule_sync).ordered

            staging_task.stage
          end
        end

        context 'when staging setup fails without a reason' do
          let(:first_reply_json) { 'invalid-json' }

          it 'raises a StagingError' do
            expect { stage }.to raise_error(CloudController::Errors::ApiError, /failed to stage/)
          end

          it 'keeps the app as not staged' do
            expect {
              ignore_staging_error { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it 'does not save the detected buildpack' do
            expect {
              ignore_staging_error { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it 'does not save the detected buildpack guid' do
            expect {
              ignore_staging_error { stage }
            }.to_not change { app.detected_buildpack_guid }.from(nil)
          end

          it 'does not save the detected start command' do
            expect {
              ignore_staging_error { stage }
            }.to_not change { app.detected_start_command }.from('')
          end

          it 'does not call provided callback (not yet)' do
            callback_called = false
            ignore_staging_error { stage { callback_called = true } }
            expect(callback_called).to be false
          end

          it 'marks the app as having failed to stage' do
            expect { ignore_staging_error { stage } }.to change { app.reload.staging_failed? }.to(true)
          end

          it 'stops the app' do
            expect { ignore_staging_error { stage } }.to change { app.reload.state }.to('STOPPED')
          end
        end

        context 'when staging setup returned an error response' do
          let(:first_reply_json_error) { 'staging failed' }

          it 'raises a StagingError' do
            expect { stage }.to raise_error(CloudController::Errors::ApiError, /failed to stage/)
          end

          it 'keeps the app as not staged' do
            expect { ignore_staging_error { stage } }.to_not change { app.staged? }.from(false)
          end

          it 'does not save the detected buildpack' do
            expect { ignore_staging_error { stage } }.to_not change { app.detected_buildpack }.from(nil)
          end

          it 'does not save the detected buildpack guid' do
            expect {
              ignore_staging_error { stage }
            }.to_not change { app.detected_buildpack_guid }.from(nil)
          end

          it 'does not save the detected start command' do
            expect { ignore_staging_error { stage } }.to_not change { app.detected_start_command }.from('')
          end

          it 'does not call provided callback (not yet)' do
            callback_called = false
            ignore_staging_error { stage { callback_called = true } }
            expect(callback_called).to be false
          end

          it 'marks the app as having failed to stage' do
            expect { ignore_staging_error { stage } }.to change { app.reload.staging_failed? }.to(true)
          end

          it 'stops the app' do
            expect { ignore_staging_error { stage } }.to change { app.reload.state }.to('STOPPED')
          end
        end

        context 'when an exception occurs' do
          def reply_with_staging_completion
            message_bus.respond_to_request("staging.#{stager_id}.start", {})
          end

          it 'copes when the app is destroyed halfway between staging (currently we dont know why this happened but seen on tabasco)' do
            allow(VCAP::CloudController::Dea::StagingResponse).to receive(:new) do
              app.destroy # We saw that app maybe destroyed half-way through staging
              raise ArgumentError.new('Some Fake Error')
            end

            expect { stage }.to raise_error ArgumentError, 'Some Fake Error'
          end
        end
      end

      describe 'receiving staging completion message' do
        def stage(&blk)
          stub_schedule_sync do
            @before_staging_completion.call if @before_staging_completion
            message_bus.respond_to_request("staging.#{stager_id}.start", first_reply_json)
          end

          staging_task.stage(&blk)
          message_bus.respond_to_request("staging.#{stager_id}.start", reply_json)
        end

        context 'when app staging succeeds' do
          let(:detected_buildpack) { 'buildpack detect output' }

          context 'when no other staging has happened' do
            before do
              allow(dea_pool).to receive(:mark_app_started)
            end

            it 'marks the app as staged' do
              expect { stage }.to change { app.refresh.staged? }.to(true)
            end

            it 'saves the detected buildpack' do
              expect { stage }.to change { app.refresh.detected_buildpack }.from(nil)
            end

            it 'saves the execution metadata' do
              expect { stage }.to change { app.refresh.execution_metadata }.from('')
            end

            context 'and the droplet has been uploaded' do
              before do
                droplet.update(state: DropletModel::STAGED_STATE, droplet_hash: 'abc')
              end

              it 'saves the detected start command' do
                expect { stage }.to change {
                  app.refresh.current_droplet
                  app.detected_start_command
                }.from('').to('wait_for_godot')
              end
            end

            context 'when the droplet somehow has not been uploaded (defensive)' do
              it 'does not change the start command' do
                expect { stage }.not_to change {
                  app.detected_start_command
                }.from('')
              end
            end

            context 'when detected_start_command is not returned' do
              let(:reply_json) do
                {
                  'task_id'                => 'task-id',
                  'task_log'               => 'task-log',
                  'task_streaming_log_url' => nil,
                  'detected_buildpack'     => detected_buildpack,
                  'buildpack_key'          => buildpack_key,
                  'error'                  => reply_json_error,
                  'error_info'             => reply_error_info,
                  'droplet_sha1'           => 'droplet-sha1'
                }
              end

              it 'does not change the detected start command' do
                expect { stage }.not_to change {
                  app.reload
                  app.detected_start_command
                }.from('')
              end
            end

            context 'when an admin buildpack is used' do
              let(:admin_buildpack) { Buildpack.make(name: 'buildpack-name') }
              let(:buildpack_key) { admin_buildpack.key }
              before do
                app.app.lifecycle_data.update(buildpack: admin_buildpack.name)
              end

              it 'saves the buildpack name' do
                expect { stage }.to change { app.refresh.detected_buildpack_name }.from(nil)
              end

              it 'saves the buildpack guid' do
                expect { stage }.to change { app.refresh.detected_buildpack_guid }.from(nil)
              end
            end

            it 'does not clobber other attributes that changed between staging' do
              # fake out the app refresh as the race happens after it
              allow(app).to receive(:refresh)

              other_app_ref         = App.find(guid: app.guid)
              other_app_ref.command = 'some other command'
              other_app_ref.save

              expect { stage }.to_not change {
                other_app_ref.refresh.command
              }
            end

            it 'marks app started in dea pool' do
              expect(dea_pool).to receive(:mark_app_started).with({ dea_id: stager_id, app_id: app.guid })
              stage
            end

            it 'calls provided callback' do
              callback_options = nil
              stage { |options| callback_options = options }
              expect(callback_options[:started_instances]).to equal(1)
            end

            it 'expires old droplets' do
              expect_any_instance_of(BitsExpiration).to receive(:expire_droplets!).with(app.app)
              stage
            end

            it 'records a buildpack set event for each process' do
              App.make(app: app.app, type: 'asdf')
              expect {
                stage
              }.to change { AppUsageEvent.where(state: 'BUILDPACK_SET').count }.to(2).from(0)
            end
          end

          context 'when other staging has happened' do
            before do
              @before_staging_completion = -> {
                DropletModel.make(app: app.app, package: app.latest_package)
              }
            end

            it 'does not mark the app as staged' do
              expect { stage rescue nil }.not_to change { app.refresh.staged? }
            end

            it 'raises a StagingError' do
              expect {
                stage
              }.to raise_error(
                CloudController::Errors::ApiError,
                /another staging request was initiated/
              )
            end

            it 'does not update droplet hash on the app' do
              expect {
                ignore_staging_error { stage }
              }.to_not change {
                app.refresh
                app.droplet_hash
              }.from(app.current_droplet.droplet_hash)
            end

            it 'does not save the detected buildpack' do
              expect {
                ignore_staging_error { stage }
              }.to_not change { app.detected_buildpack }.from(nil)
            end

            it 'does not save the detected start command' do
              expect {
                ignore_staging_error { stage }
              }.to_not change { app.detected_start_command }.from('')
            end

            it 'does not call provided callback' do
              callback_called = false
              ignore_staging_error do
                stage { callback_called = true }
              end
              expect(callback_called).to be false
            end
          end

          context 'when staging was already marked as failed' do
            before do
              @before_staging_completion = -> {
                droplet.update(state: DropletModel::FAILED_STATE)
              }
            end

            it 'does not mark the app as staged' do
              expect { stage rescue nil }.not_to change { app.refresh.staged? }
            end

            it 'raises a StagingError' do
              expect {
                stage
              }.to raise_error(
                CloudController::Errors::ApiError,
                /staging had already been marked as failed, this could mean that staging took too long/
              )
            end
          end
        end

        context 'when app staging fails without a reason' do
          let(:reply_json) { nil }
          let(:options) { { invalid_json: true } }

          it 'logs StagingError instead of raising to avoid stopping main runloop' do
            logger = double(:logger).as_null_object
            expect(logger).to receive(:error).with(/Encountered error on stager with id #{stager_id}/)

            allow(Steno).to receive_messages(logger: logger)
            stage
          end

          it 'keeps the app as not staged' do
            expect { stage }.to_not change { app.staged? }.from(false)
          end

          it 'does not save the detected buildpack' do
            expect { stage }.to_not change { app.detected_buildpack }.from(nil)
          end

          it 'does not save the detected buildpack guid' do
            expect { stage }.to_not change { app.detected_buildpack_guid }.from(nil)
          end

          it 'does not save the detected start command' do
            expect { stage }.to_not change { app.detected_start_command }.from('')
          end

          it 'does not call provided callback (not yet)' do
            callback_called = false
            stage { callback_called = true }
            expect(callback_called).to be false
          end

          it 'marks the app as having failed to stage' do
            expect { stage }.to change { app.reload.staging_failed? }.to(true)
          end

          it 'leaves the app with a generic staging failed reason' do
            expect { stage }.to change { app.reload.staging_failed_reason }.to('StagerError')
          end

          it 'stops the app' do
            expect { stage }.to change { app.reload.state }.to('STOPPED')
          end
        end

        context 'when app staging returned an error response' do
          let(:reply_json_error) { 'staging failed' }

          it 'logs StagingError instead of raising to avoid stopping main runloop' do
            logger = double(:logger).as_null_object

            expect(logger).to receive(:error) do |msg|
              expect(msg).to match(/Encountered error on stager with id #{stager_id}/)
            end

            allow(Steno).to receive_messages(logger: logger)
            stage
          end

          it 'keeps the app as not staged' do
            expect { stage }.to_not change { app.staged? }.from(false)
          end

          it 'does not save the detected buildpack' do
            expect { stage }.to_not change { app.detected_buildpack }.from(nil)
          end

          it 'does not save the detected buildpack guid' do
            expect { stage }.to_not change { app.detected_buildpack_guid }.from(nil)
          end

          it 'does not save the detected start command' do
            expect { stage }.to_not change { app.detected_start_command }.from('')
          end

          it 'does not call provided callback (not yet)' do
            callback_called = false
            stage { callback_called = true }
            expect(callback_called).to be false
          end

          it 'marks the app as having failed to stage' do
            expect { stage }.to change { app.reload.staging_failed? }.to(true)
          end

          it 'stops the app' do
            expect { stage }.to change { app.reload.state }.to('STOPPED')
          end

          context 'when a staging error is present' do
            let(:reply_error_info) { { 'type' => 'NoAppDetectedError', 'message' => 'uh oh' } }

            it 'sets the staging failed reason to the specified value' do
              expect { stage }.to change { app.reload.staging_failed_reason }.to('NoAppDetectedError')
            end

            it 'saves the corresponding api error message' do
              expect { stage }.to change { app.reload.staging_failed_description }.to('An app was not successfully detected by any available buildpack')
            end
          end

          context 'when a staging error is not present' do
            let(:reply_error_info) { nil }

            it 'sets a generic staging failed reason' do
              expect { stage }.to change { app.reload.staging_failed_reason }.to('StagerError')
            end
          end
        end
      end

      describe 'reserve app memory' do
        before do
          allow(dea_pool).to receive(:find_stager).with(app.stack.name, 1025, 4096).and_return(dea_advertisement)
        end

        context 'when app memory is less when configured minimum_staging_memory_mb' do
          before do
            config_hash[:staging][:minimum_staging_memory_mb] = 1025
          end

          it "decrement dea's available memory by minimum_staging_memory_mb" do
            expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, 1025)
            staging_task.stage
          end

          it "decrement stager's available memory by minimum_staging_memory_mb" do
            expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, 1025)
            staging_task.stage
          end
        end

        context 'when app memory is greater when configured minimum_staging_memory_mb' do
          it "decrement dea's available memory by app memory" do
            expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, 1024)
            staging_task.stage
          end

          it "decrement stager's available memory by app memory" do
            expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, 1024)
            staging_task.stage
          end
        end
      end
    end

    def stub_schedule_sync
      allow(EM).to receive(:schedule_sync) do |&blk|
        promise = VCAP::Concurrency::Promise.new

        begin
          if blk.arity > 0
            blk.call(promise)
          else
            promise.deliver(blk.call)
          end
        rescue => e
          promise.fail(e)
        end

        # Yield before trying to resolve the promise
        yield

        promise.resolve
      end
    end

    def ignore_staging_error
      yield
    rescue CloudController::Errors::ApiError => e
      raise e unless e.name == 'StagingError' || e.name == 'NoAppDetectedError' || e.name == 'StagerError'
    end
  end
end
