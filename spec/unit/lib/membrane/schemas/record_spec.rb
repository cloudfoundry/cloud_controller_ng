# frozen_string_literal: true

require_relative '../membrane_spec_helper'

RSpec.describe Membrane::Schemas::Record do
  describe '#validate' do
    it "returns an error if the validated object isn't a hash" do
      schema = Membrane::Schemas::Record.new(nil)

      expect_validation_failure(schema, 'test', /instance of Hash/)
    end

    it 'returns an error for missing keys' do
      key_schemas = { 'foo' => Membrane::Schemas::Any.new }
      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      expect_validation_failure(rec_schema, {}, /foo => Missing/)
    end

    it 'validates the value for each key' do
      data = {
        'foo' => 1,
        'bar' => 2
      }

      key_schemas = {
        'foo' => double('foo'),
        'bar' => double('bar')
      }

      key_schemas.each { |k, m| expect(m).to receive(:validate).with(data[k]) }

      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      rec_schema.validate(data)
    end

    it "returns all errors for keys or values that didn't validate" do
      key_schemas = {
        'foo' => Membrane::Schemas::Any.new,
        'bar' => Membrane::Schemas::Class.new(String)
      }

      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      errors = nil

      begin
        rec_schema.validate({ 'bar' => 2 })
      rescue Membrane::SchemaValidationError => e
        errors = e.to_s
      end

      expect(errors).to match(/foo => Missing key/)
      expect(errors).to match(/bar/)
    end

    it 'ignores extra keys that are not in the schema' do
      data = {
        'key' => 'value',
        'other_key' => 2
      }

      rec_schema = Membrane::Schemas::Record.new({
                                                   'key' => Membrane::Schemas::Class.new(String)
                                                 })

      expect do
        rec_schema.validate(data)
      end.not_to raise_error
    end

    context "when ENV['MEMBRANE_ERROR_USE_QUOTES'] is set" do
      it 'returns an error message that can be parsed' do
        ENV['MEMBRANE_ERROR_USE_QUOTES'] = 'true'
        rec_schema = Membrane::SchemaParser.parse do
          { 'a_number' => Integer,
            'tf' => bool,
            'seventeen' => 17,
            'nested_hash' => Membrane::SchemaParser.parse { { size: Float } } }
        end
        error_message = nil
        begin
          rec_schema.validate(
            { 'tf' => 'who knows', 'seventeen' => 18,
              'nested_hash' => { size: 17, color: 'blue' } }
          )
        rescue Membrane::SchemaValidationError => e
          error_message = e.to_s
        end
        expect(error_message).to include("'tf' => %q(Expected instance of true or false, given who knows)")
        expect(error_message).to include("'a_number' => %q(Missing key)")
        expect(error_message).to include("'seventeen' => %q(Expected 17, given 18)")
        expect(error_message).to include("'nested_hash' => %q({ 'size' => %q(Expected instance of Float, given an instance of Integer) })")
        ENV.delete('MEMBRANE_ERROR_USE_QUOTES')
      end
    end
  end

  describe '#parse' do
    it 'allows chaining/inheritance of schemas' do
      base_schema = Membrane::SchemaParser.parse do
        {
          'key' => String
        }
      end

      specific_schema = base_schema.parse do
        {
          'another_key' => String
        }
      end

      input_hash = {
        'key' => 'value',
        'another_key' => 'another value'
      }
      expect(specific_schema.validate(input_hash)).to be_nil
    end
  end
end
