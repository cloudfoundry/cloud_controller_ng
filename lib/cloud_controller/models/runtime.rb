# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Runtime < Sequel::Model
    plugin :serialization

    one_to_many :apps

    default_order_by  :name
    export_attributes :name, :description, :version, :internal_info
    import_attributes :name, :description, :internal_info

    strip_attributes  :name

    serialize_attributes :json, :internal_info

    def validate
      validates_presence :name
      validates_presence :description
      validates_presence :internal_info
      validates_unique   :name
    end

    def version
      internal_info["version"] if internal_info
    end

    def self.populate_from_file(file_name)
      populate_from_hash YAML.load_file(file_name)
    end

    def self.populate_from_hash(config)
      config.each do |key, rt|
        Runtime.update_or_create(:name => key) do |r|
          r.update(
            :description => rt["description"],
            :internal_info => rt
          )
        end
      end
    end
  end
end
