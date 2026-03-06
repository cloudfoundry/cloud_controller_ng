# frozen_string_literal: true

require_relative 'membrane_spec_helper'

RSpec.describe Membrane::SchemaParser do
  let(:parser) { Membrane::SchemaParser.new }

  describe '#deparse' do
    it 'calls inspect on the value of a Value schema' do
      val = 'test'
      schema = Membrane::Schemas::Value.new(val)

      # Just verify it returns the inspected value
      expect(parser.deparse(schema)).to eq val.inspect
    end

    it "returns 'any' for instance of Membrane::Schemas::Any" do
      schema = Membrane::Schemas::Any.new

      expect(parser.deparse(schema)).to eq 'any'
    end

    it "returns 'bool' for instances of Membrane::Schemas::Bool" do
      schema = Membrane::Schemas::Bool.new

      expect(parser.deparse(schema)).to eq 'bool'
    end

    it 'calls name on the class of a Membrane::Schemas::Class schema' do
      klass = String
      schema = Membrane::Schemas::Class.new(klass)

      # Just verify it returns the class name
      expect(parser.deparse(schema)).to eq klass.name
    end

    it 'deparses the k/v schemas of a Membrane::Schemas::Dictionary schema' do
      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = Membrane::Schemas::Class.new(Integer)

      dict_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      expect(parser.deparse(dict_schema)).to eq 'dict(String, Integer)'
    end

    it 'deparses the element schemas of a Membrane::Schemas::Enum schema' do
      schemas =
        [String, Integer, Float].map { |c| Membrane::Schemas::Class.new(c) }

      enum_schema = Membrane::Schemas::Enum.new(*schemas)

      expect(parser.deparse(enum_schema)).to eq 'enum(String, Integer, Float)'
    end

    it 'deparses the element schema of a Membrane::Schemas::List schema' do
      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = Membrane::Schemas::Class.new(Integer)
      item_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      list_schema = Membrane::Schemas::List.new(item_schema)

      expect(parser.deparse(list_schema)).to eq '[dict(String, Integer)]'
    end

    it 'deparses elem schemas of a Membrane::Schemas::Record schema' do
      str_schema = Membrane::Schemas::Class.new(String)
      int_schema = Membrane::Schemas::Class.new(Integer)
      dict_schema = Membrane::Schemas::Dictionary.new(str_schema, int_schema)

      int_rec_schema = Membrane::Schemas::Record.new({
                                                       str: str_schema,
                                                       dict: dict_schema
                                                     })
      rec_schema = Membrane::Schemas::Record.new({
                                                   'str' => str_schema,
                                                   'rec' => int_rec_schema,
                                                   'int' => int_schema
                                                 })

      exp_deparse = <<~EXPECTED_DEPARSE
        {
          "str" => String,
          "rec" => {
            :str => String,
            :dict => dict(String, Integer),
          },
          "int" => Integer,
        }
      EXPECTED_DEPARSE
      expect(parser.deparse(rec_schema)).to eq exp_deparse.strip
    end

    it 'calls inspect on regexps for Membrane::Schemas::Regexp' do
      regexp_val = /test/
      schema = Membrane::Schemas::Regexp.new(regexp_val)

      # Just verify it returns the regexp inspected
      expect(parser.deparse(schema)).to eq regexp_val.inspect
    end

    it 'deparses the element schemas of a Membrane::Schemas::Tuple schema' do
      schemas = [String, Integer].map { |c| Membrane::Schemas::Class.new(c) }
      schemas << Membrane::Schemas::Value.new('test')

      enum_schema = Membrane::Schemas::Tuple.new(*schemas)

      expect(parser.deparse(enum_schema)).to eq 'tuple(String, Integer, "test")'
    end

    it 'calls inspect on a Membrane::Schemas::Base schema' do
      schema = Membrane::Schemas::Base.new
      expect(parser.deparse(schema)).to eq schema.inspect
    end

    it 'raises an error if given a non-schema' do
      expect do
        parser.deparse({})
      end.to raise_error(ArgumentError, /Expected instance/)
    end
  end

  describe '#parse' do
    it 'leaves instances derived from Membrane::Schemas::Base unchanged' do
      old_schema = Membrane::Schemas::Any.new

      expect(parser.parse { old_schema }).to eq old_schema
    end

    it "translates 'any' into Membrane::Schemas::Any" do
      schema = parser.parse { any }

      expect(schema.class).to eq Membrane::Schemas::Any
    end

    it "translates 'bool' into Membrane::Schemas::Bool" do
      schema = parser.parse { bool }

      expect(schema.class).to eq Membrane::Schemas::Bool
    end

    it "translates 'enum' into Membrane::Schemas::Enum" do
      schema = parser.parse { enum(bool, any) }

      expect(schema.class).to eq Membrane::Schemas::Enum

      expect(schema.elem_schemas.length).to eq 2

      elem_schema_classes = schema.elem_schemas.map(&:class)

      expected_classes = [Membrane::Schemas::Bool, Membrane::Schemas::Any]
      expect(elem_schema_classes).to eq expected_classes
    end

    it "translates 'dict' into Membrane::Schemas::Dictionary" do
      schema = parser.parse { dict(String, Integer) }

      expect(schema.class).to eq Membrane::Schemas::Dictionary

      expect(schema.key_schema.class).to eq Membrane::Schemas::Class
      expect(schema.key_schema.klass).to eq String

      expect(schema.value_schema.class).to eq Membrane::Schemas::Class
      expect(schema.value_schema.klass).to eq Integer
    end

    it "translates 'tuple' into Membrane::Schemas::Tuple" do
      schema = parser.parse { tuple(String, any, Integer) }

      expect(schema.class).to eq Membrane::Schemas::Tuple

      expect(schema.elem_schemas[0].class).to eq Membrane::Schemas::Class
      expect(schema.elem_schemas[0].klass).to eq String

      schema.elem_schemas[1].class

      expect(schema.elem_schemas[2].class).to eq Membrane::Schemas::Class
      expect(schema.elem_schemas[2].klass).to eq Integer
    end

    it 'translates classes into Membrane::Schemas::Class' do
      schema = parser.parse { String }

      expect(schema.class).to eq Membrane::Schemas::Class

      expect(schema.klass).to eq String
    end

    it 'translates regexps into Membrane::Schemas::Regexp' do
      regexp = /foo/

      schema = parser.parse { regexp }

      expect(schema.class).to eq Membrane::Schemas::Regexp

      expect(schema.regexp).to eq regexp
    end

    it 'falls back to Membrane::Schemas::Value' do
      schema = parser.parse { 5 }

      expect(schema.class).to eq Membrane::Schemas::Value
      expect(schema.value).to eq 5
    end

    describe 'when parsing a list' do
      it 'raises an error when no element schema is supplied' do
        expect do
          parser.parse { [] }
        end.to raise_error(ArgumentError, /must supply/)
      end

      it 'raises an error when supplied > 1 element schema' do
        expect do
          parser.parse { [String, String] }
        end.to raise_error(ArgumentError, /single schema/)
      end

      it "parses '[<expr>]' into Membrane::Schemas::List" do
        schema = parser.parse { [String] }

        expect(schema.class).to eq Membrane::Schemas::List

        expect(schema.elem_schema.class).to eq Membrane::Schemas::Class
        expect(schema.elem_schema.klass).to eq String
      end
    end

    describe 'when parsing a record' do
      it 'raises an error if the record is empty' do
        expect do
          parser.parse { {} }
        end.to raise_error(ArgumentError, /must supply/)
      end

      it "parses '{ <key> => <schema> }' into Membrane::Schemas::Record" do
        schema = parser.parse do
          { 'string' => String,
            'ints' => [Integer] }
        end

        expect(schema.class).to eq Membrane::Schemas::Record

        str_schema = schema.schemas['string']
        expect(str_schema.class).to eq Membrane::Schemas::Class
        expect(str_schema.klass).to eq String

        ints_schema = schema.schemas['ints']
        expect(ints_schema.class).to eq Membrane::Schemas::List
        expect(ints_schema.elem_schema.class).to eq Membrane::Schemas::Class
        expect(ints_schema.elem_schema.klass).to eq Integer
      end

      it "handles keys marked with 'optional()'" do
        schema = parser.parse { { optional('test') => Integer } }

        expect(schema.class).to eq Membrane::Schemas::Record
        expect(schema.optional_keys.to_a).to eq ['test']
      end
    end
  end
end
