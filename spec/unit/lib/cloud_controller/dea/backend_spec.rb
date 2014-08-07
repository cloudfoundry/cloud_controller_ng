require "spec_helper"

module VCAP::CloudController
  module Dea
    describe Backend do
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

      let(:app) do
        instance_double(App, guid: "fake-app-guid")
      end

      subject(:backend) do
        Backend.new(app, config, message_bus, dea_pool, stager_pool)
      end

      before do
        allow(Client).to receive(:message_bus).and_return(message_bus)
      end

      describe "#requires_restage?" do
        it "returns false" do
          expect(backend.requires_restage?).to eq(false)
        end
      end

      describe "#stage" do
        let(:stager_task) do
          double(AppStagerTask)
        end

        let(:app) do
          App.new(guid: "fake-app-guid")
        end

        before do
          allow(AppStagerTask).to receive(:new).and_return(stager_task)
          allow(backend).to receive(:start)
          allow(stager_task).to receive(:stage).and_yield("fake-staging-result").and_return("fake-stager-response")

          backend.stage
        end

        it "stages the app with a stager task" do
          expect(stager_task).to have_received(:stage)
          expect(AppStagerTask).to have_received(:new).with(config,
                                                            message_bus,
                                                            app,
                                                            dea_pool,
                                                            stager_pool,
                                                            an_instance_of(CloudController::Blobstore::UrlGenerator))
        end

        it "starts the app with the returned staging result" do
          expect(backend).to have_received(:start).with("fake-staging-result")
        end

        it "records the stager response on the app" do
          expect(app.last_stager_response).to eq("fake-stager-response")
        end
      end

      describe "#scale" do
        before do
          allow(Client).to receive(:change_running_instances)
          allow(app).to receive(:previous_changes).and_return(previous_changes)

          backend.scale
        end

        context "when the app now desires more instances than it used to" do
          let(:previous_changes) do
            {instances: [10, 15]}
          end

          it "increases the number instances" do
            expect(Client).to have_received(:change_running_instances).with(app, 5)
          end
        end

        context "when the app now desires fewer instances than it used to" do
          let(:previous_changes) do
            {instances: [10, 5]}
          end

          it "reduces the number instances" do
            expect(Client).to have_received(:change_running_instances).with(app, -5)
          end
        end
      end

      describe "#start" do
        let(:desired_instances) { 0 }

        before do
          allow(app).to receive(:instances).and_return(10)
          allow(Client).to receive(:start)
        end

        context "when started after staging (so there are existing instances)" do
          it "only starts the number of additional required" do
            staging_result = {started_instances: 5}
            backend.start(staging_result)

            expect(Client).to have_received(:start).with(app, instances_to_start: 5)
          end
        end

        context "when starting after the app was stopped" do
          it "starts the desired number of instances" do
            backend.start

            expect(Client).to have_received(:start).with(app, instances_to_start: 10)
          end
        end
      end

      describe "#stop" do
        before do
          backend.stop
        end

        it "notifies the DEA to stop the app via NATS" do
          expect(message_bus).to have_received(:publish).with("dea.stop", droplet: app.guid)
        end
      end
    end
  end
end
