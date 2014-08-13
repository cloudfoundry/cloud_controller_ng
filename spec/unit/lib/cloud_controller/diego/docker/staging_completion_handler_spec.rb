require "spec_helper"
require "cloud_controller/diego/docker/staging_completion_handler"

module VCAP::CloudController
  module Diego
    module Docker
      describe StagingCompletionHandler do
        let(:logger) do
          instance_double(Steno::Logger, info: nil)
        end

        let(:payload) do
          {}
        end

        let(:message_bus) do
          message_bus = instance_double(CfMessageBus::MessageBus)
          allow(message_bus).to receive(:subscribe).and_yield(payload)
          message_bus
        end

        let(:backend) do
          instance_double(Diego::Backend, start: nil)
        end

        let(:backends) { instance_double(Backends, find_one_to_run: backend) }

        let(:app) do
          AppFactory.make(staging_task_id: "fake-staging-task-id")
        end

        subject(:handler) do
          StagingCompletionHandler.new(message_bus, backends)
        end

        before do
          allow(Steno).to receive(:logger).with("cc.docker.stager").and_return(logger)
          allow(Loggregator).to receive(:emit_error)
        end

        it "subscribes to diego.docker.staging.finished responses" do
          handler.subscribe!
          expect(message_bus).to have_received(:subscribe).with("diego.docker.staging.finished", queue: "cc")
        end

        context "when it receives a success response" do
          let(:payload) do
            {
              "app_id" => app.guid,
              "task_id" => app.staging_task_id
            }
          end

          it "marks the app as staged" do
            expect {
              handler.subscribe!
            }.to change { app.reload.staged? }.to(true)
          end

          it "sends desires the app on Diego" do
            handler.subscribe!
            expect(backends).to have_received(:find_one_to_run).with(app)
            expect(backend).to have_received(:start)
          end

          context "when the app_id is invalid" do
            let(:payload) do
              {
                "app_id" => "bad-app-id",
              }
            end

            it "returns without sending a desire request for the app" do
              handler.subscribe!

              expect(backends).not_to have_received(:find_one_to_run)
              expect(backend).not_to have_received(:start)
            end

            it "logs info about an unknown app for the CF operator" do
              handler.subscribe!

              expect(logger).to have_received(:info).with(
                "diego.docker.staging.unknown-app",
                :response => payload
              )
            end

          end

          context "when the task_id is invalid" do
            let(:payload) do
              {
                "app_id" => app.guid,
                "task_id" => "bad-task-id"
              }
            end

            it "returns without sending a desired request for the app" do
              handler.subscribe!

              expect(backends).not_to have_received(:find_one_to_run)
              expect(backend).not_to have_received(:start)
            end

            it "logs info about an invalid task id for the CF operator and returns" do
              handler.subscribe!

              expect(logger).to have_received(:info).with(
                "diego.docker.staging.not-current",
                :response => payload,
                :current => app.staging_task_id
              )
            end
          end
        end

        context "when it receives a failure response" do
          let(:payload) do
            {
              "app_id" => app.guid,
              "task_id" => app.staging_task_id,
              "error" => "fake-error",
            }
          end

          it "marks the app as failed to stage" do
            expect {
              handler.subscribe!
            }.to change { app.reload.package_state }.to("FAILED")
          end

          it "logs an error for the CF user" do
            handler.subscribe!

            expect(Loggregator).to have_received(:emit_error).with(app.guid, /fake-error/)
          end

          it "returns without sending a desired request for the app" do
            handler.subscribe!

            expect(backends).not_to have_received(:find_one_to_run)
            expect(backend).not_to have_received(:start)
          end
        end
      end
    end
  end
end
