require 'json-schema'
require 'active_model'

module VCAP
  module Services
    module ServiceBrokers
      module V2
        class Schema
          include ActiveModel::Validations

          attr_reader :schema
          MAX_SCHEMA_SIZE = 65_536

          validates_length_of :to_json, maximum: MAX_SCHEMA_SIZE, message: 'Must not be larger than 64KB'
          validate :validate_metaschema_provided,
                   :validate_metaschema_conforms_to_json_draft,
                   :validate_open_service_broker_restrictions

          def initialize(schema)
            @schema = schema
          end

          def to_json(*_args)
            @schema.to_json
          end

          private

          def validate_metaschema_provided
            return unless errors.blank?

            add_schema_error_msg('Schema must have $schema key but was not present') unless @schema['$schema']
          end

          def validate_metaschema_conforms_to_json_draft
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
              add_schema_error_msg("Must conform to JSON Schema Draft 04 (experimental support for later versions): #{error[:message]}")
            end
          end

          def validate_open_service_broker_restrictions
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
    end
  end
end
