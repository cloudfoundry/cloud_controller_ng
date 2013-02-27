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

    def self.populate_from_directory(dir_name)
      Dir[File.join(dir_name, "*.yml")].each do |file_name|
        populate_from_file(file_name)
      end
    end

    private

    def self.populate_from_file(file_name)
      populate_from_hash(YAML.load_file(file_name))
    end

    def self.populate_from_hash(config)
      update_or_create(:name => config["name"]) do |r|
        r.update(:description => config["description"])
      end
    end
  end
end
