# frozen_string_literal: true

require_relative '../membrane_spec_helper'
require 'membrane'

RSpec.describe Membrane::Schemas::Class do
  describe '#validate' do
    let(:schema) { Membrane::Schemas::Class.new(String) }

    it 'returns nil for instances of the supplied class' do
      expect(schema.validate('test')).to be_nil
    end

    it 'returns nil for subclasses of the supplied class' do
      class StrTest < String; end

      expect(schema.validate(StrTest.new('hi'))).to be_nil
    end

    it 'returns an error for non class instances' do
      expect_validation_failure(schema, 10, /instance of String/)
    end
  end
end
