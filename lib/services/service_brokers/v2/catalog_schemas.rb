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

      validate_no_external_references(attrs)
      @create_instance = attrs
    end

    def validate_no_external_references(schema)
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(schema, {})
      rescue JSON::Schema::SchemaError => e
        errors.add("Schema not valid. Custom meta schemas are not supported. #{e}")
      rescue JSON::Schema::ReadRefused => e
        errors.add("Schema not valid. No external references are allowed: #{e}")
      rescue JSON::Schema::ValidationError
        # We only care that there are no external references.
      rescue => e
        errors.add("Schema not valid. #{e}")
      end
    end
  end
end
