require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  MAX_SCHEMA_SIZE = 65_536
  class CatalogSchemas
    attr_reader :errors, :create_instance, :update_instance

    def initialize(schemas)
      @errors = VCAP::Services::ValidationErrors.new
      @schemas = schemas

      return unless validate_structure([])

      service_instance_path = ['service_instance']
      return unless validate_structure(service_instance_path)

      @create_instance = validate_and_populate_create(service_instance_path)
      @update_instance = validate_and_populate_update(service_instance_path)
    end

    def valid?
      errors.empty?
    end

    private

    attr_reader :schemas

    def validate_structure(path)
      schema = path.reduce(@schemas) { |current, key|
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

    def validate_and_populate_create(path)
      create_path = path + ['create']
      return unless validate_structure(create_path)

      create_parameter_path = create_path + ['parameters']
      return unless validate_structure(create_parameter_path)

      create_parameters = @schemas['service_instance']['create']['parameters']

      validate_schema(create_parameter_path, create_parameters)

      return unless errors.empty?

      create_parameters
    end

    def validate_and_populate_update(path)
      update_path = path + ['update']
      return unless validate_structure(update_path)

      update_parameter_path = update_path + ['parameters']
      return unless validate_structure(update_parameter_path)

      update_parameters = @schemas['service_instance']['update']['parameters']
      validate_schema(update_parameter_path, update_parameters)
      return unless errors.empty?

      update_parameters
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
      add_schema_error_msg(path, 'Must not be larger than 64KB') if schema.to_json.length > MAX_SCHEMA_SIZE
    end

    def validate_metaschema(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)
      file = File.read(JSON::Validator.validator_for_name('draft4').metaschema)

      metaschema = JSON.parse(file)

      begin
        errors = JSON::Validator.fully_validate(metaschema, schema, errors_as_objects: true)
      rescue => e
        add_schema_error_msg(path, e)
        return nil
      end

      errors.each do |error|
        add_schema_error_msg(path, "Must conform to JSON Schema Draft 04: #{error[:message]}")
      end
    end

    def validate_no_external_references(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(schema, {})
      rescue JSON::Schema::SchemaError
        add_schema_error_msg(path, 'Custom meta schemas are not supported.')
      rescue JSON::Schema::ReadRefused => e
        add_schema_error_msg(path, "No external references are allowed: #{e}")
      rescue JSON::Schema::ValidationError
        # We don't care if our input fails validation on broker schema
      rescue => e
        add_schema_error_msg(path, e)
      end
    end

    def add_schema_error_msg(path, err)
      path = path.empty? ? '' : " #{path.join('.')}"
      errors.add("Schema#{path} is not valid. #{err}")
    end

    def add_schema_type_error_msg(path, value)
      path = path.empty? ? '' : " #{path.join('.')}"
      errors.add("Schemas#{path} must be a hash, but has value #{value.inspect}")
    end
  end
end
