RSpec::Matchers.define :have_creatable_attributes do |attributes|
  match do |controller|
    create_message = controller.const_get(:CreateMessage)
    @attribute_validator = AttributeValidator.new(create_message, attributes, "creatable")
    @attribute_validator.valid?
  end

  failure_message do |actual|
    @attribute_validator.failure_message(actual)
  end
end

RSpec::Matchers.define :have_updatable_attributes do |attributes|
  match do |controller|
    create_message = controller.const_get(:UpdateMessage)
    @attribute_validator = AttributeValidator.new(create_message, attributes, "updatable")
    @attribute_validator.valid?
  end

  failure_message do |actual|
    @attribute_validator.failure_message(actual)
  end
end

class AttributeValidator
  attr_reader :attributes, :fields, :matcher_type
  def initialize(message_class, attributes, matcher_type)
    @fields = message_class.fields
    @message_class = message_class
    @matcher_type = matcher_type

    @attributes = attributes
    @missing_attributes = []
    @unexpected_attributes = []
    @attributes_with_bad_type = []
    @attributes_with_bad_default = []
    @attributes_with_required_mismatch = []
  end

  def valid?
    attributes.each do |attribute_name, details|
      field = fields[attribute_name]
      if field
        @attributes_with_bad_default << [attribute_name, details[:default], field.default] unless details[:default] == field.default
        @attributes_with_required_mismatch << [attribute_name, details[:required]] unless !!details[:required] == field.required
        controller_type = Membrane::SchemaParser.deparse(field.schema).downcase
        @attributes_with_bad_type << [attribute_name, details[:type], controller_type] unless schema_matches?(field.schema, details[:type])
      else
        @missing_attributes << attribute_name
      end
    end
    fields.each do |attribute_name, details|
      @unexpected_attributes << attribute_name unless attributes.has_key? attribute_name
    end

    @missing_attributes.empty? &&
      @unexpected_attributes.empty? &&
      @attributes_with_bad_type.empty? &&
      @attributes_with_bad_default.empty? &&
      @attributes_with_required_mismatch.empty?
  end

  def failure_message(actual)
    error_string = "expected that #{actual} to have #{matcher_type} attributes specified by #{attributes}\nErrors:"
    if @missing_attributes.present?
      error_string << "\nAttributes expected, but not found on the Controller: #{@missing_attributes}"
    end
    if @unexpected_attributes.present?
      error_string << "\nUnexpected attributes found on the Controller: #{@unexpected_attributes}"
    end
    @attributes_with_bad_default.each do |attribute_name, expected_default, controller_default|
      error_string << "\nExpected #{attribute_name} to have default value #{expected_default.inspect}, but has default #{controller_default.inspect}"
    end
    @attributes_with_required_mismatch.each do |attribute_name, expected_to_be_required|
      if expected_to_be_required
        error_string << "\nExpected #{attribute_name} to be required but was not"
      else
        error_string << "\nExpected #{attribute_name} not to be required but it was"
      end
    end
    @attributes_with_bad_type.each do |attribute_name, expected_type, controller_type|
      error_string << "\nExpected #{attribute_name} to be of type #{expected_type}, but has type #{controller_type}"
    end
    error_string
  end

  private

  def schema_matches?(schema, expected_type)
    schema_string = Membrane::SchemaParser.deparse(schema).downcase
    if schema.instance_of? Membrane::Schemas::Record
      schema_string.gsub(/[\s,]/, "") == expected_type.gsub(/[\s,]/, "")
    else
      schema_string == expected_type
    end
  end

end
