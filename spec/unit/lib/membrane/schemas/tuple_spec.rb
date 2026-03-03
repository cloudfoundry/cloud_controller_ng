# frozen_string_literal: true

require_relative '../membrane_spec_helper'
require 'membrane'

RSpec.describe Membrane::Schemas::Tuple do
  let(:schema) do
    Membrane::Schemas::Tuple.new(Membrane::Schemas::Class.new(String),
                                 Membrane::Schemas::Any.new,
                                 Membrane::Schemas::Class.new(Integer))
  end

  describe '#validate' do
    it "raises an error if the validated object isn't an array" do
      expect_validation_failure(schema, {}, /Array/)
    end

    it 'raises an error if the validated object has too many/few items' do
      expect_validation_failure(schema, ['foo', 2], /element/)
      expect_validation_failure(schema, ['foo', 2, 'bar', 3], /element/)
    end

    it 'raises an error if any of the items do not validate' do
      expect_validation_failure(schema, [5, 2, 0], /0 =>/)
      expect_validation_failure(schema, ['foo', 2, 'foo'], /2 =>/)
    end

    it 'returns nil when validation succeeds' do
      expect(schema.validate(['foo', 'bar', 5])).to be_nil
    end
  end
end
