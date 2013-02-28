# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Stack < Sequel::Model
    plugin :serialization

    export_attributes :name, :description
    import_attributes :name, :description

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_unique   :name
    end

    def self.populate_from_file(file_name)
      config_hash = YAML.load_file(file_name)
      ConfigFileSchema.validate(config_hash)

      config_hash["stacks"].each do |stack_hash|
        populate_from_hash(stack_hash)
      end
    end

    private

    ConfigFileSchema = Membrane::SchemaParser.parse {{
      "stacks" => [{
        "name" => String,
        "description" => String,
      }]
    }}

    def self.populate_from_hash(hash)
      update_or_create(:name => hash["name"]) do |r|
        r.update(:description => hash["description"])
      end
    end
  end
end
