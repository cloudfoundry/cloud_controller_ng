require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  MAX_SCHEMA_SIZE = 65_536
  class CatalogSchemas
    attr_reader :errors, :create_instance, :update_instance

    def initialize(schema)
      @errors = VCAP::Services::ValidationErrors.new
      validate_and_populate_create_instance(schema)
      populate_update_instance(schema)
    end

    def valid?
      errors.empty?
    end

    private

    def populate_update_instance(schema)
      return unless schema
      unless schema.is_a? Hash
        return
      end

      path = []
      ['service_instance', 'update', 'parameters'].each do |key|
        path += [key]
        schema = schema[key]
        return nil unless schema
        unless schema.is_a? Hash
          return nil
        end
      end

      update_instance_schema = schema
      @update_instance = update_instance_schema
    end

    def validate_and_populate_create_instance(schema)
      return unless schema
      unless schema.is_a? Hash
        errors.add("Schemas must be a hash, but has value #{schema.inspect}")
        return
      end

      path = []
      ['service_instance', 'create', 'parameters'].each do |key|
        path += [key]
        schema = schema[key]
        return nil unless schema

        unless schema.is_a? Hash
          errors.add("Schemas #{path.join('.')} must be a hash, but has value #{schema.inspect}")
          return nil
        end
      end

      create_instance_schema = schema
      create_instance_path = path.join('.')

      validate_schema(create_instance_path, create_instance_schema)
      return unless errors.empty?

      @create_instance = create_instance_schema
    end

    def validate_schema(path, schema)
      schema_validations.each do |validation|
        break if errors.present?
        send(validation, path, schema)
      end
    end

    def schema_validations
      [
        :validate_schema_size,
        :validate_metaschema,
        :validate_no_external_references,
        :validate_schema_type
      ]
    end

    def validate_schema_type(path, schema)
      add_schema_error_msg(path, 'must have field "type", with value "object"') if schema['type'] != 'object'
    end

    def validate_schema_size(path, schema)
      errors.add("Schema #{path} is larger than 64KB") if schema.to_json.length > MAX_SCHEMA_SIZE
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
