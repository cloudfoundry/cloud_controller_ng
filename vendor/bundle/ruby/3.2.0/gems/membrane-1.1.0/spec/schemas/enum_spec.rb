require "spec_helper"

describe Membrane::Schemas::Enum do
  describe "#validate" do
    let (:int_schema) { Membrane::Schemas::Class.new(Integer) }
    let (:str_schema) { Membrane::Schemas::Class.new(String) }
    let (:enum_schema) { Membrane::Schemas::Enum.new(int_schema, str_schema) }

    it "should return an error if none of the schemas validate" do
      expect_validation_failure(enum_schema, :sym, /doesn't validate/)
    end

    it "should return nil if any of the schemas validate" do
      enum_schema.validate("foo").should be_nil
    end
  end
end
