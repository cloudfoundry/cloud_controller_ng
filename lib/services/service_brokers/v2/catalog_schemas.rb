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

      create_instance_hash = validate_and_populate_create(service_instance_path)
      update_instance_hash = validate_and_populate_update(service_instance_path)

      if create_instance_hash
        @create_instance = Schema.new(create_instance_hash, 'service_instance.create.parameters')
        if !create_instance.validate
          create_instance.errors.messages.each { |key, value| value.each { |error| errors.add(error) } }
        end
      end

      if update_instance_hash
        @update_instance = Schema.new(update_instance_hash, 'service_instance.update.parameters')
        if !update_instance.validate
          update_instance.errors.messages.each { |key, value| value.each { |error| errors.add(error) } }
        end
      end
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

      @schemas['service_instance']['create']['parameters']
    end

    def validate_and_populate_update(path)
      update_path = path + ['update']
      return unless validate_structure(update_path)

      update_parameter_path = update_path + ['parameters']
      return unless validate_structure(update_parameter_path)

      @schemas['service_instance']['update']['parameters']
    end

    def add_schema_type_error_msg(path, value)
      path = path.empty? ? '' : " #{path.join('.')}"
      errors.add("Schemas#{path} must be a hash, but has value #{value.inspect}")
    end
  end

  class Schema
    include ActiveModel::Validations

    validate :validate_schema_size, :validate_metaschema, :validate_no_external_references, :validate_schema_type

    def initialize(schema, path)
      @schema = schema
      @path = path
    end

    def validate_schema_size
      return unless errors.blank?
      add_schema_error_msg('Must not be larger than 64KB') if @schema.to_json.length > MAX_SCHEMA_SIZE
    end

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
      errors.add(:base, "Schema #{@path} is not valid. #{err}")
    end

    def add_schema_type_error_msg(value)
      errors.add(:base, "Schemas #{@path} must be a hash, but has value #{value.inspect}")
    end

    def to_json
      @schema.to_json
    end
  end
end
