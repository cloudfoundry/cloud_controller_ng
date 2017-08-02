require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  class Schema
    include ActiveModel::Validations

    MAX_SCHEMA_SIZE = 65_536

    validates :to_json, length: { maximum: MAX_SCHEMA_SIZE, message: 'Must not be larger than 64KB' }
    validate :validate_schema_type, :validate_metaschema, :validate_no_external_references

    def initialize(schema)
      @schema = schema
    end

    def to_json
      @schema.to_json
    end

    private

    def validate_schema_type
      return unless errors.blank?
      add_schema_error_msg('must have field "type", with value "object"') if @schema['type'] != 'object'
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

    def add_schema_error_msg(err)
      errors.add(:base, err.to_s)
    end
  end
end
