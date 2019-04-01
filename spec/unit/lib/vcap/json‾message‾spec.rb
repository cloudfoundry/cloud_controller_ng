# Copyright (c) 2009-2012 VMware, Inc
require 'spec_helper'
require 'vcap/json_message'

RSpec.describe JsonMessage::Field do
  it 'should raise an error when a required field is defined with a default' do
    expect {
      JsonMessage::Field.new('key', schema: String, required: true, default: 'default')
    }.to raise_error { |error|
      expect(error).to be_an_instance_of(JsonMessage::DefinitionError)
      expect(error.message.size).to be > 0
    }
  end

  expected = 'should raise a schema validation error when schema validation'
  expected << ' fails for the default value of an optional field'
  it expected do
    expect {
      JsonMessage::Field.new('optional', schema: Hash, required: false, default: 'default')
    }.to raise_error { |error|
      expect(error).to be_an_instance_of(JsonMessage::ValidationError)
      expect(error.message.size).to be > 0
    }
  end

  expected = 'should not raise a schema validation error when default value'
  expected << ' is absent for an optional field'
  it expected do
    expect {
      JsonMessage::Field.new('optional', schema: String, required: false)
    }.to_not raise_error
  end

  it 'can use a block to define the schema' do
    field = JsonMessage::Field.new('integer') { Integer }

    expect do
      field.validate('string')
    end.to raise_error(JsonMessage::ValidationError)

    expect do
      field.validate(1)
    end.to_not raise_error
  end
end

RSpec.describe JsonMessage do
  describe '#required' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'should define the field accessor' do
      @klass.required :required, String
      msg = @klass.new
      expect(msg.required).to eq(nil)
      expect { msg.required = 'required' }.to_not raise_error
    end

    it 'should define the field to be required' do
      @klass.required :required, String
      msg = @klass.new

      expect {
        msg.encode
      }.to raise_error { |error|
        expect(error).to be_an_instance_of(JsonMessage::ValidationError)
        expect(error.message.size).to be > 0
      }
    end

    it 'should assume wildcard when schema is not defined' do
      @klass.required :required
      msg = @klass.new
      expect { msg.required = Object.new }.to_not raise_error
    end
  end

  describe '#optional' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'should define the field accessor' do
      @klass.optional :optional, String
      msg = @klass.new
      expect(msg.optional).to eq(nil)
      expect { msg.optional = 'optional' }.to_not raise_error
    end

    it 'should define the field to be optional' do
      @klass.optional :optional, String
      msg = @klass.new
      expect { msg.encode }.to_not raise_error
    end

    it 'should define a default value' do
      @klass.optional :optional, String, 'default'
      msg = @klass.new
      expect(msg.optional).to eq('default')
    end

    expected = 'should assume nil as default value when not defined'
    it expected do
      @klass.optional :optional, String
      msg = @klass.new
      expect(msg.encode).to eq(Yajl::Encoder.encode({}))
    end

    it 'should assume wildcard when schema is not defined' do
      @klass.optional :optional
      msg = @klass.new
      expect { msg.optional = Object.new }.to_not raise_error
    end
  end

  describe '#initialize' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'does not raise an exception when an unknown field is given' do
      expect {
        @klass.new({ 'unknown' => 'unknown' })
      }.not_to raise_error
    end

    it 'does not add unknown fields to the result' do
      expect(@klass.new({ 'unknown' => 'unknown' })).not_to respond_to(:unknown)
    end

    expected = 'should set default value for optional field which is'
    expected << ' defined, but not initialized in constructor'
    it expected do
      @klass.optional :optional, String, 'default'
      msg = @klass.new
      expect(msg.optional).to eq('default')
    end

    expected = 'should set default value for optional field defined after'
    expected << ' object is initialized'
    it expected do
      msg = @klass.new
      @klass.optional :optional, String, 'default'
      expect(msg.optional).to eq('default')
    end

    it 'should replace a default value with a defined value' do
      @klass.optional :optional, String, 'default'
      msg = @klass.new({ 'optional' => 'defined' })
      expect(msg.optional).to eq('defined')
    end

    it 'should not set a default for a field without a default value' do
      @klass.optional :optional, String
      msg = @klass.new
      expect(msg.optional).to eq(nil)
    end

    it 'should set the default value for a required field with false default value' do
      @klass.optional :enabled, -> { bool }, false
      msg = @klass.new
      expect(msg.enabled).to eq(false)
    end
  end

  describe '#encode' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'should encode uninitialized optional attribute with default value' do
      msg = @klass.new
      @klass.optional :optional, String, 'default'
      expect(msg.encode).to eq(Yajl::Encoder.encode({ 'optional' => 'default' }))
    end

    it 'should raise validation errors when required fields are missing' do
      @klass.required :required_one, String
      @klass.required :required_two, String
      msg = @klass.new

      expect { msg.encode }.to raise_error { |error|
        expect(error).to be_a(JsonMessage::ValidationError)
        expect(error.message).to be_an_instance_of(String)
        expect(error.message.size).to be > 0
      }
    end

    it 'should encode fields' do
      @klass.required :required, String
      @klass.optional :with_default, String, 'default'
      @klass.optional :no_default, String

      msg = @klass.new
      msg.required = 'required'
      msg.no_default = 'defined'

      expected = {
                  'required' => 'required',
                  'with_default' => 'default',
                  'no_default' => 'defined'
                 }
      received = Yajl::Parser.parse(msg.encode)
      expect(received).to eq(expected)
    end
  end

  describe '#decode' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'should raise a parse error when malformed json is passed' do
      expect { @klass.decode('blah') }.to raise_error { |error|
        expect(error).to be_an_instance_of(JsonMessage::ParseError)
        expect(error.message.size).to be > 0
      }
    end

    it 'should raise a parse error when json passed is nil' do
      expect { @klass.decode(nil) }.to raise_error { |error|
        expect(error).to be_an_instance_of(JsonMessage::ParseError)
        expect(error.message.size).to be > 0
      }
    end

    it 'should raise validation errors when required fields are missing' do
      @klass.required :required_one, String
      @klass.required :required_two, String

      expect {
        @klass.decode(Yajl::Encoder.encode({}))
      }.to raise_error { |error|
        expect(error).to be_a(JsonMessage::ValidationError)
        expect(error.message.size).to be > 0
      }
    end

    it 'should decode json' do
      @klass.required :required, String
      @klass.optional :with_default, String, 'default'
      @klass.optional :no_default, String
      encoded = Yajl::Encoder.encode({
                                       'required' => 'required',
                                       'no_default' => 'defined'
                                     })
      decoded = @klass.decode(encoded)
      expect(decoded.required).to eq('required')
      expect(decoded.with_default).to eq('default')
      expect(decoded.no_default).to eq('defined')
    end
  end

  describe '#extract' do
    before :each do
      @klass = Class.new(JsonMessage)
    end

    it 'should extract fields' do
      @klass.required :required, String
      @klass.optional :optional, String, 'default'
      msg = @klass.new
      msg.required = 'required'

      extracted = msg.extract
      expect(extracted).to eq({ required: 'required', optional: 'default' })

      extracted = msg.extract(stringify_keys: true)
      expect(extracted).to eq({ 'required' => 'required', 'optional' => 'default' })
    end
  end
end
