require "spec_helper"

module VCAP::CloudController
  describe RackAppBuilder do
    subject(:builder) do
      RackAppBuilder.new
    end

    describe "#build" do
      before do
        allow(Rack::CommonLogger).to receive(:new)
      end

      it "returns a Rack application" do
        expect(builder.build(config)).to be_a(Rack::Builder)
        expect(builder.build(config)).to respond_to(:call)
      end

      it "uses Rack::CommonLogger" do
        builder.build(config).to_app

        expect(Rack::CommonLogger).to have_received(:new)
      end

      it "uses Rack::Timeout to interrupt requests that take more than configured" do
        builder.build(config).to_app

        expect(Rack::Timeout.timeout).to eq(RackAppBuilder::TIMEOUT)
        expect(RackAppBuilder::TIMEOUT).to eq(5.minutes)
      end
    end
  end
end
