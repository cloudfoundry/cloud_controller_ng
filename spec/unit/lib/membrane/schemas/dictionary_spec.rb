# frozen_string_literal: true

require_relative '../membrane_spec_helper'

RSpec.describe Membrane::Schemas::Dictionary do
  describe '#validate' do
    let(:data) { { 'foo' => 1, 'bar' => 2 } }

    it 'returns an error if supplied with a non-hash' do
      schema = Membrane::Schemas::Dictionary.new(nil, nil)

      expect_validation_failure(schema, 'test', /instance of Hash/)
    end

    it 'validates each key against the supplied key schema' do
      key_schema = double('key_schema')

      data.each_key { |k| expect(key_schema).to receive(:validate).with(k) }

      dict_schema = Membrane::Schemas::Dictionary.new(key_schema,
                                                      Membrane::Schemas::Any.new)

      dict_schema.validate(data)
    end

    it 'validates the value for each valid key' do
      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = double('val_schema')

      data.each_value { |v| expect(val_schema).to receive(:validate).with(v) }

      dict_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      dict_schema.validate(data)
    end

    it "returns any errors for keys or values that didn't validate" do
      bad_data = {
        'foo' => 'bar',
        :bar => 2
      }

      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = Membrane::Schemas::Class.new(Integer)
      dict_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      errors = nil

      begin
        dict_schema.validate(bad_data)
      rescue Membrane::SchemaValidationError => e
        errors = e.to_s
      end

      expect(errors).to match(/foo/)
      expect(errors).to match(/bar/)
    end
  end
end
