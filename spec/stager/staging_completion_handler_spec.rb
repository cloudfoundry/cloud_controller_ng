require "spec_helper"

module VCAP::CloudController
  describe StagingCompletionHandler do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    let(:environment) { {} }

    let(:staged_app) { App.make(instances: 3, staging_task_id: "the-staging-task-id", environment_json: environment) }

    let(:logger) { FakeLogger.new([]) }

    let(:app_id) { staged_app.guid }

    let(:buildpack) { Buildpack.make }

    let(:response) do
      {
        "app_id" => app_id,
        "task_id" => staged_app.staging_task_id,
        "detected_buildpack" => 'INTERCAL',
        "buildpack_key" => buildpack.key,
      }
    end

    let(:diego_client) { double(:diego_client) }

    subject { StagingCompletionHandler.new(message_bus, diego_client) }

    before do
      Steno.stub(:logger).and_return(logger)
      DeaClient.stub(:start)

      staged_app.add_new_droplet("lol")
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

      describe "success cases" do
        context "when a detected start command is returned" do
          before { response["detected_start_command"] = "./some-start-command" }

          it "saves it on the app's current droplet" do
            publish_staging_result

            staged_app.current_droplet.detected_start_command.should == "./some-start-command"
          end
        end

        context "without the DIEGO_RUN_BETA flag" do
          it "starts the app instances" do
            DeaClient.should_receive(:start) do |received_app, received_hash|
              received_app.guid.should ==  app_id
              received_hash.should  == {:instances_to_start => 3}
            end
            diego_client.should_not_receive(:send_desire_request)
            publish_staging_result
          end

          it 'logs the staging result' do
            publish_staging_result
            logger.log_messages.should include("diego.staging.finished")
          end

          it 'should update the app with the detected buildpack' do
            publish_staging_result
            staged_app.reload
            staged_app.detected_buildpack.should == 'INTERCAL'
            staged_app.detected_buildpack_guid.should == buildpack.guid
          end
        end

        context "with the CF_DIEGO_RUN_BETA flag" do
          let(:environment) { {"CF_DIEGO_RUN_BETA" => "true"} }

          it "desires the app using the diego client" do
            DeaClient.should_not_receive(:start)
            diego_client.should_receive(:send_desire_request) do |received_app|
              received_app.guid.should ==  app_id
            end
            publish_staging_result
          end
        end
      end

      describe "failure cases" do
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
            staged_app.reload
            staged_app.detected_buildpack.should_not == 'INTERCAL'
            staged_app.detected_buildpack_guid.should_not == buildpack.guid
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
            staged_app.reload
            staged_app.detected_buildpack.should_not == 'INTERCAL'
            staged_app.detected_buildpack_guid.should_not == buildpack.guid
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
end
