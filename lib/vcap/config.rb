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
      end

      def validate(config_hash)
        schema.validate(config_hash)
        parent_schema.validate(config_hash) if parent_schema
      end
    end
  end
end
