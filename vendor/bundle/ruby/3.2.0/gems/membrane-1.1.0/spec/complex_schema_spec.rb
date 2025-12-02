require "spec_helper"

describe Membrane do
  let(:schema) do
    Membrane::SchemaParser.parse do
      { "ints"       => [Integer],
        "tf"         => bool,
        "any"        => any,
        "1_or_2"     => enum(1, 2),
        "str_to_str_to_int" => dict(String, dict(String, Integer)),
        optional("optional") => bool,
      }
    end
  end

  let(:valid) do
    { "ints"       => [1, 2],
      "tf"         => false,
      "any"        => nil,
      "1_or_2"     => 2,
      "optional"   => true,
      "str_to_str_to_int" => { "ten" => { "twenty" => 20 } },
    }
  end

  it "should work with complex nested schemas" do
    schema.validate(valid).should be_nil
  end

  it "should complain about missing keys" do
    required_keys = schema.schemas.keys.dup
    required_keys.delete("optional")

    required_keys.each do |k|
      invalid = valid.dup

      invalid.delete(k)

      expect_validation_failure(schema, invalid, /#{k} => Missing key/)
    end
  end

  it "should validate nested maps" do
    invalid = valid.dup

    invalid["str_to_str_to_int"]["ten"]["twenty"] = "invalid"

    expect_validation_failure(schema, invalid, /twenty => Expected/)
  end
end
