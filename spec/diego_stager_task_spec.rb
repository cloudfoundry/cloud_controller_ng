require "spec_helper"

module VCAP::CloudController
  describe DiegoStagerTask do
    FakeLogger = Struct.new(:log_messages) do
      def info(message, _)
        log_messages << message
      end
    end

    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:config_hash) { { diego: true } }
    let(:app) do
      AppFactory.make(:package_hash  => "abc",
                      :droplet_hash  => "I DO NOTHING",
                      :package_state => "PENDING",
                      :state         => "STARTED",
                      :instances     => 1)
    end
    let(:blobstore_url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }
    let(:completion_callback) { lambda {|x| return x } }

    before do
      EM.stub(:add_timer)
      EM.stub(:defer).and_yield
    end

    describe '#stage' do
      let(:logger) { FakeLogger.new([]) }

      before do
        Steno.stub(:logger).and_return(logger)
      end

      let(:diego_stager_task) { DiegoStagerTask.new(config_hash, message_bus, app, blobstore_url_generator) }

      def perform_stage
        diego_stager_task.stage &completion_callback
      end

      it 'assigns a new staging_task_id to the app being staged' do
        perform_stage
        app.staging_task_id.should_not be_nil
        app.staging_task_id.should == diego_stager_task.task_id
      end

      it 'logs the beginning of staging' do
        logger.should_receive(:info).with('staging.begin', { app_guid: app.guid })
        perform_stage
      end

      it 'publishes the diego.staging.start message' do
        perform_stage
        expect(message_bus.published_messages.first).
            to include(subject: "diego.staging.start", message: diego_stager_task.staging_request)
      end

      it 'the diego.staging.start message includes a stack' do
        perform_stage
        expect(message_bus.published_messages.first[:message]).
            to include(
                   stack: app.stack.name
               )
      end

      context 'when staging finishes' do
        before do
          message_bus.stub(:request).and_yield(response, 'I am an ignored inbox parameter')
        end

        context 'when the staging successfully completes' do
          let(:response) { {'task_log' => double(:task_log), 'detected_buildpack' => 'INTERCAL'} }

          it 'logs the staging result' do

            perform_stage
            logger.log_messages.include?("diego.staging.response")
          end

          it 'should update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should == 'INTERCAL'
          end

          it 'should call the completion callback' do
            completion_callback.should_receive(:call)
            perform_stage
          end

          context 'when another staging task has started' do
            before do
              app.stub(:staging_task_id).and_return('another-task-id')
            end

            it 'should not update the app with a detected buildpack' do
              perform_stage
              app.detected_buildpack.should_not == 'INTERCAL'
            end

            it 'should not call the completion callback' do
              completion_callback.should_not_receive(:call)
              perform_stage
            end
          end
        end

        context 'when the staging fails' do
          let(:response) { {"error" => "Sumpin' bad happened"} }

          before do
            message_bus.stub(:request).and_yield(response, nil)
          end

          it 'should mark the app as "failed to stage"' do
            app.should_receive(:mark_as_failed_to_stage)
            perform_stage
          end

          it 'should emit a loggregator error' do
            Loggregator.should_receive(:emit_error).with(app.guid, /bad/)
            perform_stage
          end

          it 'should not update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should_not == 'INTERCAL'
          end

          it 'should not call the completion callback' do
            completion_callback.should_not_receive(:call)
            perform_stage
          end

        end

        context 'when there is a message bus timeout' do
          let(:response) { {"timeout" => true} }

          it 'should mark the app as "failed to stage"' do
            app.should_receive(:mark_as_failed_to_stage)
            perform_stage
          end

          it 'should emit a loggregator error' do
            Loggregator.should_receive(:emit_error).with(app.guid, /timed out/)
            perform_stage
          end

          it 'should not update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should_not == 'INTERCAL'
          end

          it 'should not call the completion callback' do
            completion_callback.should_not_receive(:call)
            perform_stage
          end
        end
      end
    end
  end
end