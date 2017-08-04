module VCAP::Services::ServiceBrokers::V2
  class Schemas
    include CatalogValidationHelper

    attr_reader :errors, :schemas, :service_instance, :service_binding

    def initialize(schemas)
      @errors = VCAP::Services::ValidationErrors.new
      @schemas = schemas

      @service_instance_data = schemas['service_instance']
      @service_binding_data = schemas['service_binding']

      build_instance
      build_binding
    end

    def build_instance
      return unless @service_instance_data
      @service_instance = ServiceInstanceSchema.new(@service_instance_data) if @service_instance_data.is_a?(Hash)
    end

    def build_binding
      return unless @service_binding_data
      @service_binding = ServiceBindingSchema.new(@service_binding_data) if @service_binding_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid
      if @service_instance_data
        validate_hash!(:service_instance, @service_instance_data)
        errors.add_nested(service_instance, service_instance.errors) if service_instance && !service_instance.valid?
      end

      if @service_binding_data
        validate_hash!(:service_binding, @service_binding_data)
        errors.add_nested(service_binding, service_binding.errors) if service_binding && !service_binding.valid?
      end
      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        service_instance: 'Service instance schema',
        service_binding: 'Service binding schema',
      }.fetch(name) { raise NotImplementedError }
    end
  end

  class ServiceInstanceSchema
    include CatalogValidationHelper

    attr_reader :errors, :instance, :create, :update

    def initialize(instance)
      @errors = VCAP::Services::ValidationErrors.new
      @instance = instance

      @create_data = instance['create']
      @update_data = instance['update']

      build_create
      build_update
    end

    def build_create
      return unless @create_data
      @create = ParametersSchema.new(@create_data) if @create_data.is_a?(Hash)
    end

    def build_update
      return unless @update_data
      @update = ParametersSchema.new(@update_data) if @update_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid
      if @create_data
        validate_hash!(:create, @create_data)
        errors.add_nested(create, create.errors) if create && !create.valid?
      end

      if @update_data
        validate_hash!(:update, @update_data)
        errors.add_nested(update, update.errors) if update && !update.valid?
      end
      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        create: 'Instance create schema',
        update: 'Instance update schema',
      }.fetch(name) { raise NotImplementedError }
    end
  end

  class ServiceBindingSchema
    include CatalogValidationHelper

    attr_reader :errors, :instance, :create

    def initialize(instance)
      @errors = VCAP::Services::ValidationErrors.new
      @instance = instance
      @create_data = instance['create']

      build_create
    end

    def build_create
      return unless @create_data
      @create = ParametersSchema.new(@create_data) if @create_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid
      if @create_data
        validate_hash!(:create, @create_data)
        errors.add_nested(create, create.errors) if create && !create.valid?
      end
      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        create: 'Binding create schema',
      }.fetch(name) { raise NotImplementedError }
    end
  end

  class ParametersSchema
    include CatalogValidationHelper

    attr_reader :errors, :parameters, :schema

    def initialize(parameters)
      @errors = VCAP::Services::ValidationErrors.new
      @parameters = parameters
      @parameters_data = parameters['parameters']

      build_schema
    end

    def build_schema
      return unless @parameters_data
      @schema = Schema.new(@parameters_data) if @parameters_data.is_a?(Hash)
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
          errors.add("Schema is not valid. #{error_msg}")
        end
      end
    end

    def human_readable_attr_name(name)
      {
        schema: 'Binding create schema',
      }.fetch(name) { raise NotImplementedError }
    end
  end

  class CatalogSchemas
    attr_reader :errors, :create_instance, :update_instance, :create_binding

    def initialize(schemas)
      @errors = VCAP::Services::ValidationErrors.new
      return unless schemas
      return unless validate_structure(schemas, [])

      setup_instance_schemas(schemas)
      setup_binding_schemas(schemas)
    end

    def setup_instance_schemas(schemas)
      path = ['service_instance']
      if validate_structure(schemas, path)
        create_schema = get_method_params(path + ['create'], schemas)
        @create_instance = Schema.new(create_schema) if create_schema

        update_schema = get_method_params(path + ['update'], schemas)
        @update_instance = Schema.new(update_schema) if update_schema
      end
    end

    def setup_binding_schemas(schemas)
      path = ['service_binding']
      if validate_structure(schemas, path)
        binding_schema = get_method_params(path + ['create'], schemas)
        @create_binding = Schema.new(binding_schema) if binding_schema
      end
    end

    def valid?
      return false unless errors.empty?

      if create_instance && !create_instance.validate
        add_schema_validation_errors(create_instance.errors, 'service_instance.create.parameters')
      end

      if update_instance && !update_instance.validate
        add_schema_validation_errors(update_instance.errors, 'service_instance.update.parameters')
      end

      if create_binding && !create_binding.validate
        add_schema_validation_errors(create_binding.errors, 'service_binding.create.parameters')
      end

      errors.empty?
    end

    private

    def validate_structure(schemas, path)
      unless schemas.is_a? Hash
        add_schema_type_error_msg(path, schemas)
        return false
      end
      schema = path.reduce(schemas) { |current, key|
        return false unless current.key?(key)
        current.fetch(key)
      }
      return false unless schema

      unless schema.is_a? Hash
        add_schema_type_error_msg(path, schema)
        return false
      end

      true
    end

    def get_method_params(path, schema)
      return unless validate_structure(schema, path)

      path << 'parameters'
      return unless validate_structure(schema, path)

      schema.dig(*path)
    end

    def add_schema_type_error_msg(path, value)
      path = path.empty? ? '' : " #{path.join('.')}"
      errors.add("Schemas#{path} must be a hash, but has value #{value.inspect}")
    end

    def add_schema_validation_errors(schema_errors, path)
      schema_errors.messages.each do |_, error_list|
        error_list.each do |error_msg|
          errors.add("Schema #{path} is not valid. #{error_msg}")
        end
      end
    end
  end
end
