require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  MAX_SCHEMA_SIZE = 65_536
  class CatalogSchemas
    attr_reader :errors, :create_instance, :update_instance

    def initialize(schemas)
      @errors = VCAP::Services::ValidationErrors.new
      @schemas = schemas
      return unless schemas

      return unless validate_structure(@schemas, [])
      service_instance_path = ['service_instance']
      return unless validate_structure(@schemas, service_instance_path)

      create_schema = get_method('create', @schemas)
      @create_instance = Schema.new(create_schema) if create_schema

      update_schema = get_method('update', @schemas)
      @update_instance = Schema.new(update_schema) if update_schema
    end

    def valid?
      return false unless errors.empty?

      if create_instance && !create_instance.validate
        add_schema_validation_errors(create_instance.errors, 'service_instance.create.parameters')
      end

      if update_instance && !update_instance.validate
        add_schema_validation_errors(update_instance.errors, 'service_instance.update.parameters')
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

    def get_method(method, schema)
      path = ['service_instance', method]
      return unless validate_structure(schema, path)

      path = ['service_instance', method, 'parameters']
      return unless validate_structure(schema, path)

      schema['service_instance'][method]['parameters']
    end

    def add_schema_validation_errors(schema_errors, path)
      schema_errors.messages.each do |_, error_list|
        error_list.each do |error_msg|
          errors.add("Schema #{path} is not valid. #{error_msg}")
        end
      end
    end

    def add_schema_type_error_msg(path, value)
      path = path.empty? ? '' : " #{path.join('.')}"
      errors.add("Schemas#{path} must be a hash, but has value #{value.inspect}")
    end
  end

  class Schema
    include ActiveModel::Validations

    validates :to_json, length: { maximum: MAX_SCHEMA_SIZE, message: 'Must not be larger than 64KB' }
    validate :validate_metaschema, :validate_no_external_references, :validate_schema_type

    def initialize(schema)
      @schema = schema
    end

    def to_json
      @schema.to_json
    end

    private

    def validate_metaschema
      return unless errors.blank?
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)
      file = File.read(JSON::Validator.validator_for_name('draft4').metaschema)

      metaschema = JSON.parse(file)

      begin
        errors = JSON::Validator.fully_validate(metaschema, @schema, errors_as_objects: true)
      rescue => e
        add_schema_error_msg(e)
        return nil
      end

      errors.each do |error|
        add_schema_error_msg("Must conform to JSON Schema Draft 04: #{error[:message]}")
      end
    end

    def validate_no_external_references
      return unless errors.blank?
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(@schema, {})
      rescue JSON::Schema::SchemaError
        add_schema_error_msg('Custom meta schemas are not supported.')
      rescue JSON::Schema::ReadRefused => e
        add_schema_error_msg("No external references are allowed: #{e}")
      rescue JSON::Schema::ValidationError
        # We don't care if our input fails validation on broker schema
      rescue => e
        add_schema_error_msg(e)
      end
    end

    def validate_schema_type
      return unless errors.blank?
      add_schema_error_msg('must have field "type", with value "object"') if @schema['type'] != 'object'
    end

    def add_schema_error_msg(err)
      errors.add(:base, err.to_s)
    end
  end
end
