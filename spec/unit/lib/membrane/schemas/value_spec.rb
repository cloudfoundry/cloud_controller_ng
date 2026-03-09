# frozen_string_literal: true

require_relative '../membrane_spec_helper'

RSpec.describe Membrane::Schemas::Value do
  describe '#validate' do
    let(:schema) { Membrane::Schemas::Value.new('test') }

    it 'returns nil for values that are equal' do
      expect(schema.validate('test')).to be_nil
    end

    it 'returns an error for values that are not equal' do
      expect_validation_failure(schema, 'tast', /Expected test/)
    end
  end
end
