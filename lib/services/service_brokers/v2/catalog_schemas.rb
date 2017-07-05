require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  class CatalogSchemas
    attr_reader :errors, :create_instance

    def initialize(schema)
      @errors = VCAP::Services::ValidationErrors.new
      validate_and_populate_create_instance(schema)
    end

    def valid?
      errors.empty?
    end

    private

    def validate_and_populate_create_instance(schemas)
      return unless schemas
      unless schemas.is_a? Hash
        errors.add("Schemas must be a hash, but has value #{schemas.inspect}")
        return
      end

      path = []
      ['service_instance', 'create', 'parameters'].each do |key|
        path += [key]
        schemas = schemas[key]
        return nil unless schemas

        unless schemas.is_a? Hash
          errors.add("Schemas #{path.join('.')} must be a hash, but has value #{schemas.inspect}")
          return nil
        end
      end

      create_instance_schema = schemas
      create_instance_path = path.join('.')

      validate_schema(create_instance_path, create_instance_schema)
      return unless errors.empty?

      @create_instance = create_instance_schema
    end

    def validate_schema(path, schema)
      validate_schema_size(path, schema)
      return unless errors.empty?
      validate_metaschema(path, schema)
      return unless errors.empty?
      validate_no_external_references(path, schema)
      return unless errors.empty?
      validate_schema_type(path, schema)
    end

    def validate_schema_type(path, schema)
      add_schema_error_msg(path, 'must have field "type", with value "object"') if schema['type'] != 'object'
    end

    def validate_schema_size(path, schema)
      if schema.to_json.length > 65_536
        errors.add("Schema #{path} is larger than 64KB")
      end
    end

    def validate_metaschema(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)
      file = File.read(JSON::Validator.validator_for_name('draft4').metaschema)

      metaschema = JSON.parse(file)

      begin
        errors = JSON::Validator.fully_validate(metaschema, schema)
      rescue => e
        add_schema_error_msg(path, e)
        return nil
      end

      errors.each do |error|
        add_schema_error_msg(path, "Must conform to JSON Schema Draft 04: #{error}")
      end
    end

    def validate_no_external_references(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(schema, {})
      rescue JSON::Schema::SchemaError => e
        add_schema_error_msg(path, "Custom meta schemas are not supported: #{e}")
      rescue JSON::Schema::ReadRefused => e
        add_schema_error_msg(path, "No external references are allowed: #{e}")
      rescue JSON::Schema::ValidationError
        # We don't care if our input fails validation on broker schema
      rescue => e
        add_schema_error_msg(path, e)
      end
    end

    def add_schema_error_msg(path, err)
      errors.add("Schema #{path} is not valid. #{err}")
    end
  end
end
