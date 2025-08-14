require 'ostruct'

module OpenApiAutoGenerator
  def self.schema_from_message(message_class, openapi_spec)
    return nil unless message_class.respond_to?(:validators) && message_class.respond_to?(:allowed_keys)

    schema = {
      'type' => 'object',
      'properties' => {},
      'required' => []
    }

    message_class.validators.each do |validator|
      next unless validator.respond_to?(:attributes)

      validator.attributes.each do |attr|
        # Clean the attribute name by removing colon prefix
        clean_attr = attr.to_s.gsub(/^:/, '')

        schema['required'] << clean_attr if validator.is_a?(ActiveModel::Validations::PresenceValidator)

        schema['properties'][clean_attr] = case validator
                                           when ActiveModel::Validations::PresenceValidator
                                             { 'type' => 'string' } # Assuming string for presence validation
                                           when ActiveModel::Validations::FormatValidator
                                             if validator.options[:with]
                                               pattern = validator.options[:with]
                                               # Handle lambda patterns
                                               pattern = pattern.respond_to?(:source) ? pattern.source : pattern.to_s
                                               { 'type' => 'string', 'pattern' => pattern }
                                             else
                                               { 'type' => 'string' }
                                             end
                                           when ActiveModel::Validations::InclusionValidator
                                             { 'type' => 'string', 'enum' => validator.options[:in] }
                                           when ActiveModel::Validations::NumericalityValidator
                                             { 'type' => 'integer' }
                                           when VCAP::CloudController::AppCreateMessage::LifecycleValidator
                                             { '$ref' => '#/components/schemas/Lifecycle' }
                                           when VCAP::CloudController::Validators::ArrayValidator
                                             { 'type' => 'array', 'items' => { 'type' => 'string' } }
                                           when VCAP::CloudController::Validators::RelationshipValidator
                                             { '$ref' => '#/components/schemas/Relationship' }
                                           else
                                             # Check for boolean validators (validates :field, boolean: true)
                                             if validator.class.name.include?('BooleanValidator') ||
                                                (validator.respond_to?(:options) && validator.options[:boolean] == true)
                                               { 'type' => 'boolean' }
                                             elsif validator.respond_to?(:options) && validator.options[:string] == true
                                               { 'type' => 'string' }
                                             elsif validator.class.name.include?('NoAdditionalKeysValidator')
                                               nil # Skip this validator
                                             elsif defined?(BaseMessage) && validator.class.ancestors.include?(BaseMessage)
                                               nested_schema = schema_from_message(validator.class, openapi_spec)
                                               if nested_schema
                                                 schema_name = "#{validator.class.name.demodulize}Request"
                                                 openapi_spec['components']['schemas'][schema_name] ||= nested_schema
                                                 { '$ref' => "#/components/schemas/#{schema_name}" }
                                               else
                                                 { 'type' => 'object' }
                                               end
                                             else
                                               { 'type' => 'string' }
                                             end
                                           end
      end
    end

    message_class.allowed_keys.each do |key|
      # Clean the key name by removing colon prefix
      clean_key = key.to_s.gsub(/^:/, '')

      # Skip if we already have this property from validators
      next if schema['properties'][clean_key]

      # Infer type from key name for common patterns
      schema['properties'][clean_key] = case clean_key
                                        when 'suspended'
                                          { 'type' => 'boolean' }
                                        when /.*_id$/, 'guid'
                                          { 'type' => 'string', 'format' => 'uuid' }
                                        when 'metadata'
                                          { 'type' => 'object' }
                                        when 'relationships'
                                          { 'type' => 'object' }
                                        else
                                          { 'type' => 'string' }
                                        end
    end

    schema['properties']['lifecycle'] = { '$ref' => '#/components/schemas/BuildpackLifecycle' } if message_class.name == 'VCAP::CloudController::AppCreateMessage'

    schema['required'].uniq!
    schema
  end

  def self.schema_from_presenter(presenter_class)
    return nil unless presenter_class&.instance_methods&.include?(:to_hash)

    # Use predefined schemas based on Cloud Foundry API documentation
    schema = predefined_schema_for_presenter(presenter_class)
    return schema if schema

    # Fallback: try to generate from presenter class structure
    generate_schema_from_presenter_class(presenter_class)
  rescue StandardError => e
    puts "Warning: Could not generate schema for #{presenter_class.name}: #{e.message}"
    nil
  end

  def self.predefined_schema_for_presenter(presenter_class)
    case presenter_class.name
    when 'VCAP::CloudController::Presenters::V3::AppPresenter'
      {
        'type' => 'object',
        'properties' => {
          'guid' => { 'type' => 'string', 'format' => 'uuid' },
          'name' => { 'type' => 'string' },
          'state' => { 'type' => 'string', 'enum' => %w[STARTED STOPPED] },
          'created_at' => { 'type' => 'string', 'format' => 'date-time' },
          'updated_at' => { 'type' => 'string', 'format' => 'date-time' },
          'lifecycle' => {
            'type' => 'object',
            'properties' => {
              'type' => { 'type' => 'string', 'enum' => %w[buildpack docker] },
              'data' => { 'type' => 'object' }
            }
          },
          'relationships' => {
            'type' => 'object',
            'properties' => {
              'space' => {
                'type' => 'object',
                'properties' => {
                  'data' => {
                    'type' => 'object',
                    'properties' => {
                      'guid' => { 'type' => 'string', 'format' => 'uuid' }
                    }
                  }
                }
              },
              'current_droplet' => {
                'type' => 'object',
                'properties' => {
                  'data' => {
                    'type' => 'object',
                    'nullable' => true,
                    'properties' => {
                      'guid' => { 'type' => 'string', 'format' => 'uuid' }
                    }
                  }
                }
              }
            }
          },
          'links' => {
            'type' => 'object',
            'additionalProperties' => {
              'type' => 'object',
              'properties' => {
                'href' => { 'type' => 'string', 'format' => 'uri' },
                'method' => { 'type' => 'string' }
              }
            }
          },
          'metadata' => { '$ref' => '#/components/schemas/Metadata' }
        },
        'required' => %w[guid name state created_at updated_at lifecycle relationships links metadata]
      }
    when 'VCAP::CloudController::Presenters::V3::OrganizationPresenter'
      {
        'type' => 'object',
        'properties' => {
          'guid' => { 'type' => 'string', 'format' => 'uuid' },
          'name' => { 'type' => 'string' },
          'suspended' => { 'type' => 'boolean' },
          'created_at' => { 'type' => 'string', 'format' => 'date-time' },
          'updated_at' => { 'type' => 'string', 'format' => 'date-time' },
          'relationships' => {
            'type' => 'object',
            'properties' => {
              'quota' => {
                'type' => 'object',
                'properties' => {
                  'data' => {
                    'type' => 'object',
                    'nullable' => true,
                    'properties' => {
                      'guid' => { 'type' => 'string', 'format' => 'uuid' }
                    }
                  }
                }
              }
            }
          },
          'links' => { '$ref' => '#/components/schemas/Links' },
          'metadata' => { '$ref' => '#/components/schemas/Metadata' }
        },
        'required' => %w[guid name suspended created_at updated_at relationships links metadata]
      }
    when 'VCAP::CloudController::Presenters::V3::SpacePresenter'
      {
        'type' => 'object',
        'properties' => {
          'guid' => { 'type' => 'string', 'format' => 'uuid' },
          'name' => { 'type' => 'string' },
          'created_at' => { 'type' => 'string', 'format' => 'date-time' },
          'updated_at' => { 'type' => 'string', 'format' => 'date-time' },
          'relationships' => {
            'type' => 'object',
            'properties' => {
              'organization' => {
                'type' => 'object',
                'properties' => {
                  'data' => {
                    'type' => 'object',
                    'properties' => {
                      'guid' => { 'type' => 'string', 'format' => 'uuid' }
                    }
                  }
                }
              },
              'quota' => {
                'type' => 'object',
                'properties' => {
                  'data' => {
                    'type' => 'object',
                    'nullable' => true,
                    'properties' => {
                      'guid' => { 'type' => 'string', 'format' => 'uuid' }
                    }
                  }
                }
              }
            }
          },
          'links' => { '$ref' => '#/components/schemas/Links' },
          'metadata' => { '$ref' => '#/components/schemas/Metadata' }
        },
        'required' => %w[guid name created_at updated_at relationships links metadata]
      }
    end
  end

  def self.generate_schema_from_presenter_class(_presenter_class)
    # Try to analyze the presenter source code for common patterns
    schema = { 'type' => 'object', 'properties' => {} }

    # Get common fields from base presenter or known patterns
    common_fields = %w[guid created_at updated_at name]
    common_fields.each do |field|
      schema['properties'][field] = infer_field_type(field)
    end

    # Add metadata and links which are common in CF API
    schema['properties']['metadata'] = { '$ref' => '#/components/schemas/Metadata' }
    schema['properties']['links'] = { '$ref' => '#/components/schemas/Links' }

    schema
  end

  def self.infer_field_type(field_name)
    case field_name
    when 'guid'
      { 'type' => 'string', 'format' => 'uuid' }
    when /.*_at$/, 'created_at', 'updated_at'
      { 'type' => 'string', 'format' => 'date-time' }
    when 'name', 'description', 'title'
      { 'type' => 'string' }
    when /.*_count$/, 'version'
      { 'type' => 'integer' }
    when 'enabled', 'disabled', 'suspended'
      { 'type' => 'boolean' }
    else
      { 'type' => 'string' }
    end
  end

  def self.enhance_schema_with_db_info(schema, model_class)
    return unless model_class.respond_to?(:db_schema)

    model_class.db_schema.each do |column, db_info|
      column_str = column.to_s
      next unless schema['properties'][column_str]

      schema['properties'][column_str]['type'] = db_type_to_openapi_type(db_info[:type])
      format = db_type_to_openapi_format(db_info[:type])
      schema['properties'][column_str]['format'] = format if format
    end
  end

  def self.mock_model_for_presenter(presenter_class)
    class_name = presenter_class.name.demodulize.gsub('Presenter', '')

    # Special case for InfoPresenter
    if presenter_class.name == 'VCAP::CloudController::Presenters::V3::InfoPresenter'
      # InfoPresenter is a special case
      begin
        info = Info.new
        config = VCAP::CloudController::Config.config
        if config
          info.build = config.get(:info, :build) || ''
          info.min_cli_version = config.get(:info, :min_cli_version) || ''
          info.min_recommended_cli_version = config.get(:info, :min_recommended_cli_version) || ''
          info.custom = config.get(:info, :custom) || {}
          info.description = config.get(:info, :description) || ''
          info.name = config.get(:info, :name) || ''
          info.version = config.get(:info, :version) || 0
          info.support_address = config.get(:info, :support_address) || ''
        else
          # If config is not available, set default values
          info.build = ''
          info.min_cli_version = ''
          info.min_recommended_cli_version = ''
          info.custom = {}
          info.description = ''
          info.name = ''
          info.version = 0
          info.support_address = ''
        end
        osbapi_version_file = Rails.root.join('config/osbapi_version').to_s
        info.osbapi_version = if File.exist?(osbapi_version_file)
                                File.read(osbapi_version_file).strip
                              else
                                ''
                              end
        return info
      rescue StandardError => e
        puts "Warning: Could not create Info object: #{e.message}"
        # Fall back to a simple mock
        return OpenStruct.new(
          build: '',
          min_cli_version: '',
          min_recommended_cli_version: '',
          custom: {},
          description: '',
          name: '',
          version: 0,
          support_address: '',
          osbapi_version: ''
        )
      end
    end

    # Try different factory names
    factory_names = [
      class_name.underscore,
      class_name.underscore.singularize,
      "#{class_name.underscore}_model"
    ]

    factory_names.each do |factory_name_str|
      factory_name = factory_name_str.to_sym
      next unless FactoryBot.factories.registered?(factory_name)

      begin
        return FactoryBot.build(factory_name)
      rescue StandardError
        next
      end
    end

    nil
  end

  def self.mock_value_for_column(model_class, column_name)
    db_schema = model_class.db_schema[column_name]
    return nil unless db_schema

    case db_schema[:type]
    when :string
      'string'
    when :integer
      1
    when :boolean
      true
    when :datetime
      Time.now.utc.iso8601
    else
      'unknown'
    end
  end

  def self.generate_schema_from_hash(hash)
    properties = {}
    hash.each do |key, value|
      properties[key] = schema_for_value(value)
    end
    { 'type' => 'object', 'properties' => properties }
  end

  def self.db_type_to_openapi_type(db_type)
    case db_type
    when :string, :text
      'string'
    when :integer, :bigint
      'integer'
    when :boolean
      'boolean'
    when :datetime, :timestamp
      'string'
    when :float, :decimal
      'number'
    else
      'string'
    end
  end

  def self.db_type_to_openapi_format(db_type)
    case db_type
    when :datetime, :timestamp
      'date-time'
    when :float
      'float'
    when :decimal
      'double'
    when :bigint
      'int64'
    end
  end

  def self.schema_for_value(value)
    case value
    when Hash
      generate_schema_from_hash(value)
    when Array
      items = value.empty? ? {} : schema_for_value(value.first)
      { 'type' => 'array', 'items' => items }
    when String
      if value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        { 'type' => 'string', 'format' => 'date-time' }
      elsif value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
        { 'type' => 'string', 'format' => 'uuid' }
      else
        { 'type' => 'string' }
      end
    when Integer
      { 'type' => 'integer' }
    when TrueClass, FalseClass
      { 'type' => 'boolean' }
    when NilClass
      { 'type' => 'null' }
    else
      { 'type' => 'string' }
    end
  end
end
