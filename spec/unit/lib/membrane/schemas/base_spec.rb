# frozen_string_literal: true

require_relative "../membrane_spec_helper"
require "membrane"


RSpec.describe Membrane::Schemas::Base do
  describe "#validate" do
    let(:schema) { Membrane::Schemas::Base.new }

    it "should raise error" do
      expect { schema.validate }.to raise_error(ArgumentError, /wrong number of arguments/)
    end

    it "should deparse" do
expect(      schema.deparse).to eq schema.inspect
    end
  end
end
