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
          @schema = Membrane::Schemas::Record.new(@schema.schemas.deep_merge(parent_schema.schema.schemas),
                                                  @schema.optional_keys.merge(parent_schema.schema.optional_keys))
        end
      end

      def validate(config_hash)
        schema.validate(config_hash)
      end
    end
  end
end
