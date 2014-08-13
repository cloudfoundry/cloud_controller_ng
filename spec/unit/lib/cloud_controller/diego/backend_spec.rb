require "spec_helper"

module VCAP::CloudController
  module Diego
    describe Backend do
      let(:messenger) do
        instance_double(Messenger, send_desire_request: nil)
      end

      let(:app) do
        instance_double(App)
      end

      let (:protocol) do
        instance_double(Diego::Traditional::Protocol, desire_app_message: {})
      end

      subject(:backend) do
        Backend.new(app, messenger, protocol)
      end

      describe "#requires_restage?" do
        context "when the app has a start command" do
          before do
            allow(app).to receive(:detected_start_command).and_return("fake-start-command")
          end

          it "returns false because it has enough information to run the app" do
            expect(backend.requires_restage?).to eq(false)
          end
        end

        context "when the app does not have a start command" do
          before do
            allow(app).to receive(:detected_start_command).and_return("")
          end

          it "assumes the app was previously staged with a DEA and needs restaging to detect its start command" do
            expect(backend.requires_restage?).to eq(true)
          end
        end
      end

      describe "#stage" do
        before do
          allow(messenger).to receive(:send_stage_request)

          backend.stage
        end

        it "notifies Diego that the app needs staging" do
          expect(messenger).to have_received(:send_stage_request).with(app)
        end
      end

      describe "#scale" do
        before do
          backend.scale
        end

        it "desires an app, relying on its state to convey the change" do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe "#start" do
        before do
          backend.start
        end

        it "desires an app, relying on its state to convey the change" do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end

        it "matches the interface of the Dea::Backend even if it doesn't use all the provided arguments" do
          expect(backend.public_method(:start).arity).to eq(Dea::Backend.instance_method(:start).arity)
        end
      end

      describe "#stop" do
        before do
          backend.stop
        end

        it "desires an app, relying on its state to convey the change" do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe "#desire_app_message" do
        it "gets the procotol's desire_app_message" do
          expect(backend.desire_app_message).to eq({})
          expect(protocol).to have_received(:desire_app_message).with(app)
        end
      end
    end
  end
end
