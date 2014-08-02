require "spec_helper"

module VCAP::CloudController
  module Diego
    describe Backend do
      let(:diego_client) do
        instance_double(Client, send_desire_request: nil)
      end

      let(:app) do
        instance_double(App)
      end

      subject(:backend) do
        Backend.new(app, diego_client)
      end

      describe "#needs_staging?" do
        context "when the app thinks it needs to be staged" do
          before do
            allow(app).to receive(:needs_staging?).and_return(true)
          end

          it "returns true" do
            expect(backend.needs_staging?).to eq(true)
          end
        end

        context "when the app thinks it does not need to be staged" do
          before do
            allow(app).to receive(:needs_staging?).and_return(false)
          end

          context "and the app has a start command" do
            before do
              allow(app).to receive(:detected_start_command).and_return("fake-start-command")
            end

            it "returns false because it has enough information to run the app" do
              expect(backend.needs_staging?).to eq(false)
            end
          end

          context "when the app does not have a start command" do
            before do
              allow(app).to receive(:detected_start_command).and_return("")
            end

            it "assumes the app was previously staged with a DEA and needs restaging to detect its start command" do
              expect(backend.needs_staging?).to eq(true)
            end
          end
        end
      end

      describe "#stage" do
        before do
          allow(diego_client).to receive(:send_stage_request)
          allow(VCAP).to receive(:secure_uuid).and_return("fake-secure-uuid")

          backend.stage
        end

        it "notifies Diego that the app needs staging with a unique staging task id" do
          expect(diego_client).to have_received(:send_stage_request).with(app, "fake-secure-uuid")
        end
      end

      describe "#scale" do
        before do
          backend.scale
        end

        it "desires an app, relying on its state to convey the change" do
          expect(diego_client).to have_received(:send_desire_request).with(app)
        end
      end

      describe "#start" do
        before do
          backend.start
        end

        it "desires an app, relying on its state to convey the change" do
          expect(diego_client).to have_received(:send_desire_request).with(app)
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
          expect(diego_client).to have_received(:send_desire_request).with(app)
        end
      end
    end
  end
end
