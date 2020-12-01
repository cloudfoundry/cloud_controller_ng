require 'cloud_controller/yaml_config'
require 'yaml'
require 'membrane'
require 'active_support'
require 'active_support/core_ext'

module VCAP
  class Config
    class << self
      attr_reader :schema
      attr_accessor :parent_schema

      def define_schema(&blk)
        @schema = Membrane::SchemaParser.parse(&blk)
        if parent_schema
          @schema = deep_merge_schemas(parent_schema.schema, @schema)
        end
      end

      def validate(config_hash)
        schema.validate(config_hash)
      end

      private

      def deep_merge_schemas(left, right)
        merged_schemas_hash = left.schemas.deep_dup
        merged_optional_keys = left.optional_keys.deep_dup.merge(right.optional_keys)

        right.schemas.each do |key, right_value|
          merged_schemas_hash[key] = if left.schemas.key?(key) && left.schemas[key].is_a?(Membrane::Schemas::Record) && right_value.is_a?(Membrane::Schemas::Record)
                                       deep_merge_schemas(left.schemas[key], right_value)
                                     else
                                       right_value
                                     end
        end

        Membrane::Schemas::Record.new(merged_schemas_hash, merged_optional_keys)
      end
    end
  end
end
