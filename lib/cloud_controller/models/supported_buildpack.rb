# Copyright (c) 2011-2013 Uhuru Software, Inc.

module VCAP::CloudController::Models
  class SupportedBuildpack < Sequel::Model
    plugin :serialization

    default_order_by  :name
    export_attributes :name, :description, :buildpack, :support_url
    import_attributes :name, :description, :buildpack, :support_url

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_presence :buildpack
      validates_unique   :name
    end

    def self.populate_from_file(file_name)
      populate_from_hash YAML.load_file(file_name)
    end

    def self.populate_from_hash(config)
      config.each do |key, cf|
        SupportedBuildpack.update_or_create(:name => key) do |sb|
          sb.update(
              :description => cf["description"],
              :buildpack => cf["buildpack"],
              :support_url => cf["support_url"]
          )
        end
      end
    end
  end
end
