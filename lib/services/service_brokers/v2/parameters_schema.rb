module VCAP::Services::ServiceBrokers::V2
  class ParametersSchema
    include CatalogValidationHelper

    attr_reader :errors, :parameters

    def initialize(parent, path)
      @errors = VCAP::Services::ValidationErrors.new
      @parameters_data = parent['parameters']
      @path = path + ['parameters']

      build_schema
    end

    def build_schema
      @parameters = Schema.new(@parameters_data) if @parameters_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid

      if @parameters_data
        validate_hash!(:parameters, @parameters_data)
        add_schema_validation_errors(parameters.errors) if parameters && !parameters.valid?
      end
      @valid = errors.empty?
    end

    private

    def add_schema_validation_errors(schema_errors)
      schema_errors.messages.each_value do |error_list|
        error_list.each do |error_msg|
          errors.add("Schema #{@path.join('.')} is not valid. #{error_msg}")
        end
      end
    end

    def human_readable_attr_name(name)
      {
        parameters: "Schemas #{@path.join('.')}",
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
