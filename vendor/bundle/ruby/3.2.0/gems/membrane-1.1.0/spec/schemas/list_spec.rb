require "spec_helper"

describe Membrane::Schemas::List do
  describe "#validate" do
    it "should return an error if the validated object isn't an array" do
      schema = Membrane::Schemas::List.new(nil)

      expect_validation_failure(schema, "hi", /instance of Array/)
    end

    it "should invoke validate each list item against the supplied schema" do
      item_schema = double("item_schema")

      data = [0, 1, 2]

      data.each { |x| item_schema.should_receive(:validate).with(x) }

      list_schema = Membrane::Schemas::List.new(item_schema)

      list_schema.validate(data)
    end
  end

  it "should return an error if any items fail to validate" do
    item_schema = Membrane::Schemas::Class.new(Integer)
    list_schema = Membrane::Schemas::List.new(item_schema)

    errors = nil

    begin
      list_schema.validate([1, 2, "hi", 3, :there])
    rescue Membrane::SchemaValidationError => e
      errors = e.to_s
    end

    errors.should match(/index 2/)
    errors.should match(/index 4/)
  end

  it "should return nil if all items validate" do
    item_schema = Membrane::Schemas::Class.new(Integer)
    list_schema = Membrane::Schemas::List.new(item_schema)

    list_schema.validate([1, 2, 3]).should be_nil
  end
end
