require 'spec_helper'

RSpec.describe 'Vendored Membrane' do
  describe 'loading' do
    it 'loads the vendored membrane library' do
      # This test verifies that the vendored Membrane library is loadable
      # and provides the expected API
      expect(defined?(Membrane)).to eq('constant')
      expect(defined?(Membrane::SchemaParser)).to eq('constant')
      expect(defined?(Membrane::Schemas)).to eq('constant')
      expect(defined?(Membrane::SchemaValidationError)).to eq('constant')
    end

    it 'loads Membrane from the vendored location (not from gems)' do
      loaded_file = $LOADED_FEATURES.grep(/\/membrane\.rb/).first

      expect(loaded_file).to include('cloud_controller_ng/lib/membrane.rb')
      expect(loaded_file).not_to include('gems')
    end
  end

  describe 'basic functionality' do
    it 'can create and validate a simple schema' do
      # Verify basic Membrane functionality works
      schema = Membrane::SchemaParser.parse do
        {
          'name' => String,
          'age' => Integer
        }
      end

      expect { schema.validate({ 'name' => 'test', 'age' => 25 }) }.not_to raise_error

      expect { schema.validate({ 'name' => 'test', 'age' => 'invalid' }) }.to raise_error(Membrane::SchemaValidationError)
    end

    it 'supports optional keys (VCAP::Config pattern)' do
      schema = Membrane::SchemaParser.parse do
        {
          'required_field' => String,
          optional('optional_field') => Integer
        }
      end

      expect { schema.validate({ 'required_field' => 'value' }) }.not_to raise_error
      expect { schema.validate({ 'required_field' => 'value', 'optional_field' => 42 }) }.not_to raise_error
    end

    it 'supports nested schemas (Diego pattern)' do
      schema = Membrane::SchemaParser.parse do
        {
          'type' => enum('buildpack', 'docker'),
          'data' => {
            optional('buildpacks') => [String],
            optional('stack') => String
          }
        }
      end

      expect { schema.validate({ 'type' => 'buildpack', 'data' => { 'stack' => 'cflinuxfs3' } }) }.not_to raise_error
    end

    it 'provides Membrane::Schemas::Record API' do
      schema = Membrane::SchemaParser.parse do
        { 'key' => String }
      end

      expect(schema).to be_a(Membrane::Schemas::Record)
      expect(schema).to respond_to(:schemas)
      expect(schema).to respond_to(:optional_keys)
    end
  end

  describe 'error handling' do
    it 'raises SchemaValidationError with proper message format' do
      schema = Membrane::SchemaParser.parse do
        { 'key' => String }
      end

      expect { schema.validate({ 'key' => nil }) }.to raise_error(
        Membrane::SchemaValidationError,
        /Expected instance of String, given an instance of NilClass/
      )
    end
  end
end
