# frozen_string_literal: true

require_relative "../membrane_spec_helper"
require "membrane"

RSpec.describe Membrane::Schemas::Bool do
  describe "#validate" do
    let(:schema) { Membrane::Schemas::Bool.new }

    it "should return nil for {true, false}" do
      [true, false].each { |v| expect(schema.validate(v)).to be_nil }
    end

    it "should return an error for values not in {true, false}" do
      ["a", 1].each do |v|
        expect_validation_failure(schema, v, /true or false/)
      end
    end
  end
end
