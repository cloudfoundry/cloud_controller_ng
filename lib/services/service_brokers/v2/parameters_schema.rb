module VCAP::Services::ServiceBrokers::V2
  class ParametersSchema
    include CatalogValidationHelper

    attr_reader :errors, :parameters, :schema

    def initialize(parameters, path)
      @errors = VCAP::Services::ValidationErrors.new
      @parameters = parameters
      @parameters_data = parameters['parameters']
      @path = path + ['parameters']

      build_schema
    end

    def build_schema
      @schema = Schema.new(@parameters_data) if @parameters_data.is_a?(Hash)
    end

    def to_json
      @schema.to_json
    end

    def valid?
      return @valid if defined? @valid

      if @parameters_data
        validate_hash!(:schema, @parameters_data)
        add_schema_validation_errors(schema.errors) if schema && !schema.valid?
      end
      @valid = errors.empty?
    end

    private

    def add_schema_validation_errors(schema_errors)
      schema_errors.messages.each do |_, error_list|
        error_list.each do |error_msg|
          errors.add("Schema #{@path.join('.')} is not valid. #{error_msg}")
        end
      end
    end

    def human_readable_attr_name(name)
      {
        schema: "Schemas #{@path.join('.')}",
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
