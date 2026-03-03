# frozen_string_literal: true

require_relative '../membrane_spec_helper'
require 'membrane'

RSpec.describe Membrane::Schemas::Regexp do
  let(:schema) { Membrane::Schemas::Regexp.new(/bar/) }

  describe '#validate' do
    it "raises an error if the validated object isn't a string" do
      expect_validation_failure(schema, 5, /instance of String/)
    end

    it "raises an error if the validated object doesn't match" do
      expect_validation_failure(schema, 'invalid', /match regex/)
    end

    it 'returns nil if the validated object matches' do
      expect(schema.validate('barbar')).to be_nil
    end
  end
end
