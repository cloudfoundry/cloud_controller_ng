# Copyright (c) 2009-2011 VMware, Inc.
require 'yaml'

require 'membrane'
require 'vcap/common'

module VCAP
  class Config
    class << self
      attr_reader :schema

      def define_schema(&blk)
        @schema = Membrane::SchemaParser.parse(&blk)
      end

      def from_file(filename, symbolize_keys=true)
        config = YAML.load_file(filename)
        config = VCAP.symbolize_keys(config) if symbolize_keys
        @schema.validate(config)
        config
      end

      def to_file(config, out_filename)
        @schema.validate(config)
        File.open(out_filename, 'w+') do |f|
          YAML.dump(config, f)
        end
      end
    end
  end
end
