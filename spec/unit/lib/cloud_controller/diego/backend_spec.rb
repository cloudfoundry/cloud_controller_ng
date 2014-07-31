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
