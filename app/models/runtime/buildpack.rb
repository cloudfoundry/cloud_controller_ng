module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :key, :priority

    import_attributes :name, :key, :priority

    def self.list_admin_buildpacks(url_generator)
      self.all.map do |buildpack|
        {
          key: buildpack.key,
          url: url_generator.admin_buildpack_download_url(buildpack)
        }
      end
    end

    def validate
      validates_unique   :name
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end
  end
end