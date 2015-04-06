require 'spec_helper'

module VCAP::CloudController
  describe Dea::PackageStagerTask do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool, reserve_app_memory: nil) }
    let(:dea_pool) { double(:stager_pool, reserve_app_memory: nil) }
    let(:config_hash) { { staging: { timeout_in_seconds: 360 } } }
    let(:blobstore_url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }

    let(:package) { PackageModel.make }
    let(:stack) { 'trusty32' }
    let(:memory_limit) { 1234 }
    let(:disk_limit) { 321 }
    let(:buildpack_guid) { 'bp-guid' }
    let(:buildpack_git_url) { 'bp-git-url' }
    let(:droplet_guid) { 'drop-guid' }
    let(:log_id) { 'log-id' }
    let(:staging_message) do
      Dea::PackageDEAStagingMessage.new(
        package, droplet_guid, log_id, stack, memory_limit, disk_limit, buildpack_guid, buildpack_git_url,
        config_hash, {}, blobstore_url_generator)
    end
    let(:stager_id) { 'my_stager' }

    subject(:staging_task) { Dea::PackageStagerTask.new(config_hash, message_bus, dea_pool, stager_pool) }

    let(:first_reply_json_error) { nil }

    let(:first_reply_json) do
      {
        'task_id' => 'task-id',
        'task_log' => 'task-log',
        'task_streaming_log_url' => nil,
        'detected_buildpack' => nil,
        'detected_start_command' => nil,
        'buildpack_key' => nil,
        'error' => first_reply_json_error,
        'droplet_sha1' => nil
      }
    end

    let(:reply_json_error) { nil }
    let(:reply_error_info) { nil }

    let(:reply_json) do
      {
        'task_id' => 'task-id',
        'task_log' => 'task-log',
        'task_streaming_log_url' => nil,
        'detected_buildpack' => nil,
        'buildpack_key' => nil,
        'detected_start_command' => nil,
        'error' => reply_json_error,
        'error_info' => reply_error_info,
        'droplet_sha1' => 'droplet-sha1'
      }
    end

    let(:stack_name) { 'lucid64' }
    let(:task_id) { 'some_task_id' }

    before do
      allow(stager_pool).to receive(:find_stager).and_return(stager_id)

      allow(EM).to receive(:add_timer)
      allow(EM).to receive(:defer).and_yield
      allow(EM).to receive(:schedule_sync)
    end

    context 'when no stager can be found' do
      let(:stager_id) { nil }

      it 'should raise an error' do
        expect {
          staging_task.stage(staging_message)
        }.to raise_error(Errors::ApiError, /no available stagers/)
      end
    end

    context 'when a stager can be found' do
      it 'should stop other staging tasks' do
        expect(message_bus).to receive(:publish).with('staging.stop', hash_including({ app_id: log_id }))
        staging_task.stage(staging_message)
      end
    end

    describe 'staging stack requirements' do
      it 'should request a stager with the staging message stack' do
        expect(stager_pool).to receive(:find_stager).
          with(staging_message.stack, anything, anything).and_return(stager_id)
        staging_task.stage(staging_message)
      end
    end

    describe 'staging memory requirements' do
      it 'should request a stager with the package memory requirement' do
        expect(stager_pool).to receive(:find_stager).
          with(anything, staging_message.memory_limit, anything).and_return(stager_id)
        staging_task.stage(staging_message)
      end
    end

    describe 'staging disk requirements' do
      it 'should request a stager with enough disk' do
        expect(stager_pool).to receive(:find_stager).
          with(anything, anything, staging_message.disk_limit).and_return(stager_id)
        staging_task.stage(staging_message)
      end
    end

    it 'reserves app memory on the dea pool' do
      expect(dea_pool).to receive(:reserve_app_memory).with(stager_id, staging_message.memory_limit)
      staging_task.stage(staging_message)
    end

    it 'reserves app memory on the stager pool' do
      expect(stager_pool).to receive(:reserve_app_memory).with(stager_id, staging_message.memory_limit)
      staging_task.stage(staging_message)
    end

    describe 'receiving the first response from the stager (the staging setup completion message)' do
      def stage(&blk)
        stub_schedule_sync do
          @before_staging_completion.call if @before_staging_completion
          message_bus.respond_to_request("staging.#{stager_id}.start", first_reply_json)
        end

        response = staging_task.stage(staging_message, &blk)
        response
      end

      context 'when staging setup succeeds' do
        context 'when there are available stagers' do
          it 'stops other staging tasks and starts a new one' do
            expect(message_bus).to receive(:publish).with('staging.stop', anything)
            expect(message_bus).to receive(:publish).with('staging.my_stager.start', staging_message.staging_request)

            stage
          end
        end

        it 'does not call provided callback (not yet)' do
          callback_called = false
          stage { callback_called = true }
          expect(callback_called).to be false
        end
      end

      context 'when staging setup fails without a reason' do
        let(:first_reply_json) { 'invalid-json' }

        it 'raises a StagingError' do
          expect { stage }.to raise_error(Dea::PackageStagerTask::FailedToStage, /failed to stage/)
        end

        it 'does not call provided callback (not yet)' do
          callback_called = false
          ignore_staging_error { stage { callback_called = true } }
          expect(callback_called).to be false
        end
      end

      context 'when staging setup returned an error response' do
        let(:first_reply_json_error) { 'staging failed' }

        it 'raises a FailedToStage' do
          expect { stage }.to raise_error(Dea::PackageStagerTask::FailedToStage, /failed to stage/)
        end

        it 'does not call provided callback (not yet)' do
          callback_called = false
          ignore_staging_error { stage { callback_called = true } }
          expect(callback_called).to be false
        end
      end
    end

    describe 'receiving staging completion message' do
      def stage(&blk)
        stub_schedule_sync do
          @before_staging_completion.call if @before_staging_completion
          message_bus.respond_to_request("staging.#{stager_id}.start", first_reply_json)
        end

        staging_task.stage(staging_message, &blk)
        message_bus.respond_to_request("staging.#{stager_id}.start", reply_json)
      end

      context 'when app staging succeeds' do
        it 'calls provided callback' do
          expected_result = Dea::StagingResponse.new(reply_json)
          result = nil
          stage { |res| result = res }
          expect(result).to eq(expected_result)
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

        it 'returns an error to the callback' do
          error_message = nil
          stage do |_, error|
            error_message = error.message
          end
          expect(error_message).to include('staging failed')
        end
      end
    end

    def stub_schedule_sync(&before_resolve)
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

        # Call before_resolve block before trying to resolve the promise
        before_resolve.call

        promise.resolve
      end
    end

    def ignore_staging_error
      yield
    rescue VCAP::CloudController::Dea::PackageStagerTask::FailedToStage
    end
  end
end
