require "spec_helper"

module VCAP::CloudController
  module Dea
    describe Backend do
      let(:message_bus) do
        instance_double(CfMessageBus::MessageBus, publish: nil)
      end

      let(:app) do
        instance_double(App, guid: "fake-app-guid")
      end

      subject(:backend) do
        Backend.new(app, message_bus)
      end

      before do
        allow(Client).to receive(:message_bus).and_return(message_bus)
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
