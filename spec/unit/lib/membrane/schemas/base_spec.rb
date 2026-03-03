# frozen_string_literal: true

require_relative '../membrane_spec_helper'

RSpec.describe Membrane::Schemas::Base do
  describe '#validate' do
    let(:schema) { Membrane::Schemas::Base.new }

    it 'raises error' do
      expect { schema.validate }.to raise_error(ArgumentError, /wrong number of arguments/)
    end

    it 'deparses' do
      expect(schema.deparse).to eq schema.inspect
    end
  end
end
