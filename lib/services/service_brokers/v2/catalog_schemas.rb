require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  class CatalogSchemas
    attr_reader :errors, :create_instance

    def initialize(attrs)
      @errors = VCAP::Services::ValidationErrors.new
      validate_and_populate_create_instance(attrs)
    end

    def valid?
      errors.empty?
    end

    private

    def validate_and_populate_create_instance(attrs)
      return unless attrs
      unless attrs.is_a? Hash
        errors.add("Schemas must be a hash, but has value #{attrs.inspect}")
        return
      end

      path = []
      ['service_instance', 'create', 'parameters'].each do |key|
        path += [key]
        attrs = attrs[key]
        return nil unless attrs

        unless attrs.is_a? Hash
          errors.add("Schemas #{path.join('.')} must be a hash, but has value #{attrs.inspect}")
          return nil
        end
      end

      create_instance_path = path.join('.')
      validate_metaschema(create_instance_path, attrs)
      return unless errors.empty?
      validate_no_external_references(create_instance_path, attrs)

      @create_instance = attrs
    end

    def validate_metaschema(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: true)
      metaschema = JSON::Validator.validator_for_name('draft4').metaschema

      begin
        valid = JSON::Validator.validate(metaschema, schema)
      rescue => e
        add_schema_error_msg(path, e)
        return nil
      end

      if !valid
        add_schema_error_msg(path, 'Must conform to JSON Schema Draft 04')
      end
    end

    def validate_no_external_references(path, schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(schema, {})
      rescue JSON::Schema::SchemaError => e
        add_schema_error_msg(path, "Custom meta schemas are not supported. #{e}")
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
