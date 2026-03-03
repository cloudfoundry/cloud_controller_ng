# frozen_string_literal: true

require_relative '../membrane_spec_helper'
require 'membrane'

RSpec.describe Membrane::Schemas::List do
  describe '#validate' do
    it "returns an error if the validated object isn't an array" do
      schema = Membrane::Schemas::List.new(nil)

      expect_validation_failure(schema, 'hi', /instance of Array/)
    end

    it 'invokes validate each list item against the supplied schema' do
      item_schema = double('item_schema')

      data = [0, 1, 2]

      data.each { |x| expect(item_schema).to receive(:validate).with(x) }

      list_schema = Membrane::Schemas::List.new(item_schema)

      list_schema.validate(data)
    end
  end

  it 'returns an error if any items fail to validate' do
    item_schema = Membrane::Schemas::Class.new(Integer)
    list_schema = Membrane::Schemas::List.new(item_schema)

    errors = nil

    begin
      list_schema.validate([1, 2, 'hi', 3, :there])
    rescue Membrane::SchemaValidationError => e
      errors = e.to_s
    end

    expect(errors).to match(/index 2/)
    expect(errors).to match(/index 4/)
  end

  it 'returns nil if all items validate' do
    item_schema = Membrane::Schemas::Class.new(Integer)
    list_schema = Membrane::Schemas::List.new(item_schema)

    expect(list_schema.validate([1, 2, 3])).to be_nil
  end
end
