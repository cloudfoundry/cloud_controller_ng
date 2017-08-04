module VCAP::Services::ServiceBrokers::V2
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
