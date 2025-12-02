require "spec_helper"

describe Membrane::Schemas::Regexp do
  let(:schema) { Membrane::Schemas::Regexp.new(/bar/) }

  describe "#validate" do
    it "should raise an error if the validated object isn't a string" do
      expect_validation_failure(schema, 5, /instance of String/)
    end

    it "should raise an error if the validated object doesn't match" do
      expect_validation_failure(schema, "invalid", /match regex/)
    end

    it "should return nil if the validated object matches" do
      schema.validate("barbar").should be_nil
    end
  end
end
