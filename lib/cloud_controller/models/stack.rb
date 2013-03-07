# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Stack < Sequel::Model
    class MissingConfigFileError < StandardError; end
    class MissingDefaultStackError < StandardError; end

    plugin :serialization

    export_attributes :name, :description
    import_attributes :name, :description

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_unique   :name
    end

    def self.configure(file_path)
      @config_file = if file_path
        ConfigFile.new(file_path).tap { |c| c.load }
      else
        nil
      end
    end

    def self.populate
      raise MissingConfigFileError unless @config_file

      @config_file.stacks.each do |stack_hash|
        populate_from_hash(stack_hash)
      end
    end

    def self.default
      raise MissingConfigFileError unless @config_file

      self[:name => @config_file.default].tap do |found_stack|
        unless found_stack
          raise MissingDefaultStackError,
            "Default stack with name '#{@config_file.default}' not found"
        end
      end
    end

    private

    def self.populate_from_hash(hash)
      update_or_create(:name => hash["name"]) do |r|
        r.update(:description => hash["description"])
      end
    end

    class ConfigFile
      def initialize(file_path)
        @file_path = file_path
      end

      def load
        @hash = YAML.load_file(@file_path).tap do |h|
          Schema.validate(h)
        end
      end

      def stacks; @hash["stacks"]; end
      def default; @hash["default"]; end

      private

      Schema = Membrane::SchemaParser.parse {{
        "default" => String,
        "stacks" => [{
          "name" => String,
          "description" => String,
        }]
      }}
    end
  end
end
