require "spec_helper"

describe Membrane::SchemaParser do
  let(:parser) { Membrane::SchemaParser.new }

  describe "#deparse" do
    it "should call inspect on the value of a Value schema" do
      val = "test"
      val.should_receive(:inspect).twice
      schema = Membrane::Schemas::Value.new(val)

      parser.deparse(schema).should == val.inspect
    end

    it "should return 'any' for instance of Membrane::Schemas::Any" do
      schema = Membrane::Schemas::Any.new

      parser.deparse(schema).should == "any"
    end

    it "should return 'bool' for instances of Membrane::Schemas::Bool" do
      schema = Membrane::Schemas::Bool.new

      parser.deparse(schema).should == "bool"
    end

    it "should call name on the class of a Membrane::Schemas::Class schema" do
      klass = String
      klass.should_receive(:name).twice
      schema = Membrane::Schemas::Class.new(klass)

      parser.deparse(schema).should == klass.name
    end

    it "should deparse the k/v schemas of a Membrane::Schemas::Dictionary schema" do
      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = Membrane::Schemas::Class.new(Integer)

      dict_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      parser.deparse(dict_schema).should == "dict(String, Integer)"
    end

    it "should deparse the element schemas of a Membrane::Schemas::Enum schema" do
      schemas =
        [String, Integer, Float].map { |c| Membrane::Schemas::Class.new(c) }

      enum_schema = Membrane::Schemas::Enum.new(*schemas)

      parser.deparse(enum_schema).should == "enum(String, Integer, Float)"
    end

    it "should deparse the element schema of a Membrane::Schemas::List schema" do
      key_schema = Membrane::Schemas::Class.new(String)
      val_schema = Membrane::Schemas::Class.new(Integer)
      item_schema = Membrane::Schemas::Dictionary.new(key_schema, val_schema)

      list_schema = Membrane::Schemas::List.new(item_schema)

      parser.deparse(list_schema).should == "[dict(String, Integer)]"
    end

    it "should deparse elem schemas of a Membrane::Schemas::Record schema" do
      str_schema = Membrane::Schemas::Class.new(String)
      int_schema = Membrane::Schemas::Class.new(Integer)
      dict_schema = Membrane::Schemas::Dictionary.new(str_schema, int_schema)

      int_rec_schema = Membrane::Schemas::Record.new({
                                                     :str => str_schema,
                                                     :dict => dict_schema
                                                    })
      rec_schema = Membrane::Schemas::Record.new({
                                                  "str" => str_schema,
                                                  "rec" => int_rec_schema,
                                                  "int" => int_schema
                                                })

      exp_deparse =<<EOT
{
  "str" => String,
  "rec" => {
    :str => String,
    :dict => dict(String, Integer),
  },
  "int" => Integer,
}
EOT
      parser.deparse(rec_schema).should == exp_deparse.strip
    end

    it "should call inspect on regexps for Membrane::Schemas::Regexp" do
      schema = Membrane::Schemas::Regexp.new(/test/)
      schema.regexp.should_receive(:inspect)
      parser.deparse(schema)
    end

    it "should deparse the element schemas of a Membrane::Schemas::Tuple schema" do
      schemas = [String, Integer].map { |c| Membrane::Schemas::Class.new(c) }
      schemas << Membrane::Schemas::Value.new("test")

      enum_schema = Membrane::Schemas::Tuple.new(*schemas)

      parser.deparse(enum_schema).should == 'tuple(String, Integer, "test")'
    end

    it "should call inspect on a Membrane::Schemas::Base schema" do
      schema = Membrane::Schemas::Base.new
      parser.deparse(schema).should == schema.inspect
    end

    it "should raise an error if given a non-schema" do
      expect do
        parser.deparse({})
      end.to raise_error(ArgumentError, /Expected instance/)
    end
  end

  describe "#parse" do
    it "should leave instances derived from Membrane::Schemas::Base unchanged" do
      old_schema = Membrane::Schemas::Any.new

      parser.parse { old_schema }.should == old_schema
    end

    it "should translate 'any' into Membrane::Schemas::Any" do
      schema = parser.parse { any }

      schema.class.should == Membrane::Schemas::Any
    end

    it "should translate 'bool' into Membrane::Schemas::Bool" do
      schema = parser.parse { bool }

      schema.class.should == Membrane::Schemas::Bool
    end

    it "should translate 'enum' into Membrane::Schemas::Enum" do
      schema = parser.parse { enum(bool, any) }

      schema.class.should == Membrane::Schemas::Enum

      schema.elem_schemas.length.should == 2

      elem_schema_classes = schema.elem_schemas.map { |es| es.class }

      expected_classes = [Membrane::Schemas::Bool, Membrane::Schemas::Any]
      elem_schema_classes.should == expected_classes
    end

    it "should translate 'dict' into Membrane::Schemas::Dictionary" do
      schema = parser.parse { dict(String, Integer) }

      schema.class.should == Membrane::Schemas::Dictionary

      schema.key_schema.class.should == Membrane::Schemas::Class
      schema.key_schema.klass.should == String

      schema.value_schema.class.should == Membrane::Schemas::Class
      schema.value_schema.klass.should == Integer
    end

    it "should translate 'tuple' into Membrane::Schemas::Tuple" do
      schema = parser.parse { tuple(String, any, Integer) }

      schema.class.should == Membrane::Schemas::Tuple

      schema.elem_schemas[0].class.should == Membrane::Schemas::Class
      schema.elem_schemas[0].klass.should == String

      schema.elem_schemas[1].class == Membrane::Schemas::Any

      schema.elem_schemas[2].class.should == Membrane::Schemas::Class
      schema.elem_schemas[2].klass.should == Integer
    end

    it "should translate classes into Membrane::Schemas::Class" do
      schema = parser.parse { String }

      schema.class.should == Membrane::Schemas::Class

      schema.klass.should == String
    end

    it "should translate regexps into Membrane::Schemas::Regexp" do
      regexp = /foo/

      schema = parser.parse { regexp }

      schema.class.should == Membrane::Schemas::Regexp

      schema.regexp.should == regexp
    end

    it "should fall back to Membrane::Schemas::Value" do
      schema = parser.parse { 5 }

      schema.class.should == Membrane::Schemas::Value
      schema.value.should == 5
    end

    describe "when parsing a list" do
      it "should raise an error when no element schema is supplied" do
        expect do
          parser.parse { [] }
        end.to raise_error(ArgumentError, /must supply/)
      end

      it "should raise an error when supplied > 1 element schema" do
        expect do
          parser.parse { [String, String] }
        end.to raise_error(ArgumentError, /single schema/)
      end

      it "should parse '[<expr>]' into Membrane::Schemas::List" do
        schema = parser.parse { [String] }

        schema.class.should == Membrane::Schemas::List

        schema.elem_schema.class.should == Membrane::Schemas::Class
        schema.elem_schema.klass.should == String
      end
    end

    describe "when parsing a record" do
      it "should raise an error if the record is empty" do
        expect do
          parser.parse { {} }
        end.to raise_error(ArgumentError, /must supply/)
      end

      it "should parse '{ <key> => <schema> }' into Membrane::Schemas::Record" do
        schema = parser.parse do
          { "string" => String,
            "ints"   => [Integer],
          }
        end

        schema.class.should == Membrane::Schemas::Record

        str_schema = schema.schemas["string"]
        str_schema.class.should == Membrane::Schemas::Class
        str_schema.klass.should == String

        ints_schema = schema.schemas["ints"]
        ints_schema.class.should == Membrane::Schemas::List
        ints_schema.elem_schema.class.should == Membrane::Schemas::Class
        ints_schema.elem_schema.klass.should == Integer
      end

      it "should handle keys marked with 'optional()'" do
        schema = parser.parse { { optional("test") => Integer } }

        schema.class.should == Membrane::Schemas::Record
        schema.optional_keys.to_a.should == ["test"]
      end
    end
  end
end
