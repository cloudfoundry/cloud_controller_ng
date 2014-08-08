require "spec_helper"

module VCAP::CloudController
  describe StagingCompletionHandler do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    let(:environment) { {} }

    let(:staged_app) { App.make(instances: 3, staging_task_id: "the-staging-task-id", environment_json: environment) }

    let(:logger) { FakeLogger.new([]) }

    let(:app_id) { staged_app.guid }

    let(:buildpack) { Buildpack.make }

    let(:success_response) do
      {
          "app_id" => app_id,
          "task_id" => staged_app.staging_task_id,
          "detected_buildpack" => 'INTERCAL',
          "buildpack_key" => buildpack.key,
      }
    end

    let(:malformed_success_response) do
      success_response.except("detected_buildpack")
    end

    let(:fail_response) do
      {
        "app_id" => app_id,
        "task_id" => staged_app.staging_task_id,
        "error" => "Sumpin' bad happened",
      }
    end

    let(:malformed_fail_response) do
      fail_response.except("task_id")
    end

    let(:diego_messenger) { instance_double(Diego::Messenger) }

    subject { StagingCompletionHandler.new(message_bus, diego_messenger) }

    before do
      allow(Steno).to receive(:logger).and_return(logger)
      allow(Dea::Client).to receive(:start)

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

      def publish_staging_result(response)
        message_bus.publish("diego.staging.finished", response)
      end

      describe "success cases" do
        it "marks the app as staged" do
          expect {
            publish_staging_result(success_response)
          }.to change { staged_app.reload.staged? }.to(true)
        end

        context "when a detected start command is returned" do
          before { success_response["detected_start_command"] = "./some-start-command" }

          it "updates the droplet with the returned start command" do
            publish_staging_result(success_response)
            staged_app.reload
            expect(staged_app.current_droplet.detected_start_command).to eq("./some-start-command")
            expect(staged_app.current_droplet.droplet_hash).to eq("lol")
          end
        end

        context "when running in diego is not enabled" do
          it "starts the app instances" do
            expect(Dea::Client).to receive(:start) do |received_app, received_hash|
              expect(received_app.guid).to eq(app_id)
              expect(received_hash).to  eq({:instances_to_start => 3})
            end
            expect(diego_messenger).not_to receive(:send_desire_request)
            publish_staging_result(success_response)
          end

          it 'logs the staging result' do
            publish_staging_result(success_response)
            expect(logger.log_messages).to include("diego.staging.finished")
          end

          it 'should update the app with the detected buildpack' do
            publish_staging_result(success_response)
            staged_app.reload
            expect(staged_app.detected_buildpack).to eq('INTERCAL')
            expect(staged_app.detected_buildpack_guid).to eq(buildpack.guid)
          end
        end

        context "when running in diego is enabled" do
          let(:environment) { {"CF_DIEGO_RUN_BETA" => "true"} }

          it "desires the app using the diego client" do
            expect(Dea::Client).not_to receive(:start)
            expect(diego_messenger).to receive(:send_desire_request) do |received_app|
              expect(received_app.guid).to eq(app_id)
            end
            publish_staging_result(success_response)
          end
        end
      end

      describe "failure cases" do
        context 'when another staging task has started' do
          before do
            success_response["task_id"] = 'another-task-id'
          end

          it "does not start the app instances" do
            expect(Dea::Client).not_to receive(:start)
            publish_staging_result(success_response)
          end

          it 'should not update the app with a detected buildpack' do
            publish_staging_result(success_response)
            staged_app.reload
            expect(staged_app.detected_buildpack).not_to eq('INTERCAL')
            expect(staged_app.detected_buildpack_guid).not_to eq(buildpack.guid)
          end
        end

        context 'when the staging fails' do
          it 'should mark the app as "failed to stage"' do
            publish_staging_result(fail_response)
            expect(staged_app.reload.package_state).to eq("FAILED")
          end

          it 'should emit a loggregator error' do
            expect(Loggregator).to receive(:emit_error).with(staged_app.guid, /bad/)
            publish_staging_result(fail_response)
          end

          it "should not start the app instance" do
            expect(Dea::Client).not_to receive(:start)
            publish_staging_result(fail_response)
          end

          it 'should not update the app with the detected buildpack' do
            publish_staging_result(fail_response)
            staged_app.reload
            expect(staged_app.detected_buildpack).not_to eq('INTERCAL')
            expect(staged_app.detected_buildpack_guid).not_to eq(buildpack.guid)
          end
        end

        context "when staging references an unknown app" do
          let(:app_id) { "ooh ooh ah ah" }

          it "should not attempt to start anything" do
            expect(Dea::Client).not_to receive(:start)
            publish_staging_result(success_response)
          end
        end

        context "with a malformed success message" do
          it "should not start anything" do
            expect(Dea::Client).not_to receive(:start)
            publish_staging_result(malformed_success_response)
          end
        end

        context "with a malformed error message" do
          it "should not emit any loggregator messages" do
            expect(Loggregator).not_to receive(:emit_error).with(staged_app.guid, /bad/)
            publish_staging_result(malformed_fail_response)
          end
        end
      end
    end
  end
end
