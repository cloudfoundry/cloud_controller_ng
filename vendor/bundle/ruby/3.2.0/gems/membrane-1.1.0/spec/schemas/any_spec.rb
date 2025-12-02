require "spec_helper"

describe Membrane::Schemas::Any do
  describe "#validate" do
    it "should always return nil" do
      schema = Membrane::Schemas::Any.new
      # Smoke test more than anything. Cannot validate this with 100%
      # certainty.
      [1, "hi", :test, {}, []].each do |o|
        schema.validate(o).should be_nil
      end
    end
  end
end
