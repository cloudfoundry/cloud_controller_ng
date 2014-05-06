require "spec_helper"

module VCAP::CloudController
  describe StagingCompletionHandler do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    let!(:staged_app) { App.make(instances: 3, staging_task_id: "the-staging-task-id") }

    let(:logger) { FakeLogger.new([]) }

    let(:app_id) { staged_app.guid }

    let(:response) do
      {
        "app_id" => app_id,
        "task_id" => staged_app.staging_task_id,
        "task_log" => double(:task_log),
        "detected_buildpack" => 'INTERCAL'
      }
    end

    subject { StagingCompletionHandler.new(message_bus) }

    before do
      Steno.stub(:logger).and_return(logger)
      DeaClient.stub(:start)
    end

    describe "#subscribe!" do
      it "subscribes to diego.staging.finished with a queue" do
        expect(message_bus).to receive(:subscribe).with("diego.staging.finished", queue: "cc")
        subject.subscribe!
      end
    end

    context "when subscribed" do
      before { subject.subscribe! }

      def publish_staging_result
        message_bus.publish("diego.staging.finished", response)
      end

      describe "when staging completes succesfully" do
        context "and no other staging task has started" do
          it "starts the app instances" do
            DeaClient.should_receive(:start) do |received_app, received_hash|
              received_app.guid.should ==  app_id
              received_hash.should  == {:instances_to_start => 3}
            end
            publish_staging_result
          end

          it 'logs the staging result' do
            publish_staging_result
            logger.log_messages.should include("diego.staging.finished")
          end

          it 'should update the app with the detected buildpack' do
            publish_staging_result
            staged_app.reload.detected_buildpack.should == 'INTERCAL'
          end
        end

        context 'when another staging task has started' do
          before do
            response["task_id"] = 'another-task-id'
          end

          it "does not start the app instances" do
            DeaClient.should_not_receive(:start)
            publish_staging_result
          end

          it 'should not update the app with a detected buildpack' do
            publish_staging_result
            staged_app.reload.detected_buildpack.should_not == 'INTERCAL'
          end
        end
      end

      context 'when the staging fails' do
        before do
          response["error"] = "Sumpin' bad happened"
        end

        it 'should mark the app as "failed to stage"' do
          publish_staging_result
          expect(staged_app.reload.package_state).to eq("FAILED")
        end

        it 'should emit a loggregator error' do
          Loggregator.should_receive(:emit_error).with(staged_app.guid, /bad/)
          publish_staging_result
        end

        it "should not start the app instance" do
          DeaClient.should_not_receive(:start)
          publish_staging_result
        end

        it 'should not update the app with the detected buildpack' do
          publish_staging_result
          staged_app.reload.detected_buildpack.should_not == 'INTERCAL'
        end
      end

      context "when staging references an unkown app" do
        let(:app_id) { "ooh ooh ah ah" }

        it "should not attempt to start anything" do
          DeaClient.should_not_receive(:start)
          publish_staging_result
        end
      end
    end
  end
end
