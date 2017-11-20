require 'yaml'
require 'membrane'

module VCAP
  class Config
    class << self
      attr_reader :schema

      def define_schema(&blk)
        @schema = Membrane::SchemaParser.parse(&blk)
      end

      def from_file(filename, symbolize_keys=true)
        config = YAML.load_file(filename)
        config = symbolize_keys(config) if symbolize_keys
        @schema.validate(config)
        config
      end

      def to_file(config, out_filename)
        @schema.validate(config)
        File.open(out_filename, 'w+') do |f|
          YAML.dump(config, f)
        end
      end

      private

      def symbolize_keys(hash)
        if hash.is_a? Hash
          new_hash = {}
          hash.each { |k, v| new_hash[k.to_sym] = symbolize_keys(v) }
          new_hash
        else
          hash
        end
      end
    end
  end
end
