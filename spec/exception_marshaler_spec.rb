require "spec_helper"

module VCAP::CloudController
  describe ExceptionMarshaler do
    let(:exception) { RuntimeError.new("failure message!") }
    subject(:exception_marshaler) { ExceptionMarshaler }

    describe "#marshal" do
      it "delegates to YAML.dump" do
        expect(YAML).to receive(:dump).with(exception).and_return("foo")

        expect(ExceptionMarshaler.marshal(exception)).to eq("foo")
      end
    end

    describe "#unmarshal" do
      it "delegates to YAML.load" do
        expect(YAML).to receive(:load).with("yaml").and_return("foo")

        expect(ExceptionMarshaler.unmarshal("yaml")).to eq("foo")
      end
    end

    describe "marshaling and unmarshaling" do
      it "should be a no-op" do
        marshaled = ExceptionMarshaler.marshal(exception)
        expect(ExceptionMarshaler.unmarshal(marshaled)).to eq(exception)
      end
    end
  end
end