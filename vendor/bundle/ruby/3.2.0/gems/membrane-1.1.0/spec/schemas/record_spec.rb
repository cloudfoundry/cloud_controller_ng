require "spec_helper"

describe Membrane::Schemas::Record do
  describe "#validate" do
    it "should return an error if the validated object isn't a hash" do
      schema = Membrane::Schemas::Record.new(nil)

      expect_validation_failure(schema, "test", /instance of Hash/)
    end

    it "should return an error for missing keys" do
      key_schemas = { "foo" => Membrane::Schemas::Any.new }
      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      expect_validation_failure(rec_schema, {}, /foo => Missing/)
    end

    it "should validate the value for each key" do
      data = {
        "foo" => 1,
        "bar" => 2,
      }

      key_schemas = {
        "foo" => double("foo"),
        "bar" => double("bar"),
      }

      key_schemas.each { |k, m| m.should_receive(:validate).with(data[k]) }

      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      rec_schema.validate(data)
    end

    it "should return all errors for keys or values that didn't validate" do
      key_schemas = {
        "foo" => Membrane::Schemas::Any.new,
        "bar" => Membrane::Schemas::Class.new(String),
      }

      rec_schema = Membrane::Schemas::Record.new(key_schemas)

      errors = nil

      begin
        rec_schema.validate({ "bar" => 2 })
      rescue Membrane::SchemaValidationError => e
        errors = e.to_s
      end

      errors.should match(/foo => Missing key/)
      errors.should match(/bar/)
    end

    context "when strict checking" do
      it "raises an error if there are extra keys that are not matched in the schema" do
        data = {
          "key" => "value",
          "other_key" => 2,
        }

        rec_schema = Membrane::Schemas::Record.new({
          "key" => Membrane::Schemas::Class.new(String)
        }, [], true)

        expect {
          rec_schema.validate(data)
        }.to raise_error(/other_key .* was not specified/)
      end
    end

    context "when not strict checking" do
      it "doesnt raise an error" do
        data = {
          "key" => "value",
          "other_key" => 2,
        }

        rec_schema = Membrane::Schemas::Record.new({
          "key" => Membrane::Schemas::Class.new(String)
        })

        expect {
          rec_schema.validate(data)
        }.to_not raise_error
      end
    end

    context "when ENV['MEMBRANE_ERROR_USE_QUOTES'] is set" do
      it "returns an error message that can be parsed" do
        ENV['MEMBRANE_ERROR_USE_QUOTES'] = 'true'
        rec_schema = Membrane::SchemaParser.parse do
          { "a_number"    => Integer,
            "tf"          => bool,
            "seventeen"   => 17,
            "nested_hash" => Membrane::SchemaParser.parse { { size: Float } }
          }
        end
        error_hash = nil
        begin
          rec_schema.validate(
            { 'tf' => 'who knows', 'seventeen' => 18,
              'nested_hash' => { size: 17, color: 'blue' } })
        rescue Membrane::SchemaValidationError => e
          error_hash = eval(e.to_s)
        end
        error_hash.should include(
          'tf' => 'Expected instance of true or false, given who knows')
        error_hash.should include(
          'a_number' => 'Missing key')
        error_hash.should include(
          'seventeen' => 'Expected 17, given 18')
        error_hash.should include('nested_hash')
        eval(error_hash['nested_hash']).should include(
          'size' => 'Expected instance of Float, given an instance of Fixnum')
        ENV.delete('MEMBRANE_ERROR_USE_QUOTES')
      end
    end
  end

  describe "#parse" do
    it "allows chaining/inheritance of schemas" do
      base_schema = Membrane::SchemaParser.parse{{
        "key" => String
      }}

      specific_schema = base_schema.parse{{
        "another_key" => String
      }}

      input_hash = {
        "key" => "value",
        "another_key" => "another value",
      }
      specific_schema.validate(input_hash).should == nil
    end
  end
end
