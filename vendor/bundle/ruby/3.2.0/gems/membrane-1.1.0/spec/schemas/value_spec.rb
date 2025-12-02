require "spec_helper"


describe Membrane::Schemas::Value do
  describe "#validate" do
    let(:schema) { Membrane::Schemas::Value.new("test") }

    it "should return nil for values that are equal" do
      schema.validate("test").should be_nil
    end

    it "should return an error for values that are not equal" do
      expect_validation_failure(schema, "tast", /Expected test/)
    end
  end
end
