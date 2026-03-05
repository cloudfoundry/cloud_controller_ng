# frozen_string_literal: true

require_relative '../membrane_spec_helper'

RSpec.describe Membrane::Schemas::Any do
  describe '#validate' do
    it 'alwayses return nil' do
      schema = Membrane::Schemas::Any.new
      # Smoke test more than anything. Cannot validate this with 100%
      # certainty.
      [1, 'hi', :test, {}, []].each do |o|
        expect(schema.validate(o)).to be_nil
      end
    end
  end
end
