require "spec_helper"


describe Membrane::Schemas::Base do
  describe "#validate" do
    let(:schema) { Membrane::Schemas::Base.new }

    it "should raise error" do
      expect { schema.validate }.to raise_error
    end

    it "should deparse" do
      schema.deparse.should == schema.inspect
    end
  end
end
