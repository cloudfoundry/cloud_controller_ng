module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :priority

    import_attributes :name, :key, :priority

    def self.list_admin_buildpacks(url_generator)
      all.map do |bp|
        {
          key: bp.key,
          url: url_generator.admin_buildpack_download_url(bp)
        }
      end
    end

    def staging_message
      { buildpack_key: self.key }
    end

    def validate
      validates_unique :name
      validates_format(/^(\w|\-)+$/, :name, :message => "name can only contain alphanumeric characters")
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    def to_json
      %Q("#{name}")
    end
  end
end