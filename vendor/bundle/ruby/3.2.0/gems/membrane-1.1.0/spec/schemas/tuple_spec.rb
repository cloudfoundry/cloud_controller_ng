require "spec_helper"

describe Membrane::Schemas::Tuple do
  let(:schema) do
    Membrane::Schemas::Tuple.new(Membrane::Schemas::Class.new(String),
                                Membrane::Schemas::Any.new,
                                Membrane::Schemas::Class.new(Integer))
  end

  describe "#validate" do
    it "should raise an error if the validated object isn't an array" do
      expect_validation_failure(schema, {}, /Array/)
    end

    it "should raise an error if the validated object has too many/few items" do
      expect_validation_failure(schema, ["foo", 2], /element/)
      expect_validation_failure(schema, ["foo", 2, "bar", 3], /element/)
    end

    it "should raise an error if any of the items do not validate" do
      expect_validation_failure(schema, [5, 2, 0], /0 =>/)
      expect_validation_failure(schema, ["foo", 2, "foo"], /2 =>/)
    end

    it "should return nil when validation succeeds" do
      schema.validate(["foo", "bar", 5]).should be_nil
    end
  end
end
