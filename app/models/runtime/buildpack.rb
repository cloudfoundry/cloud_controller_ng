module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :key, :priority

    import_attributes :name, :key, :priority

    def self.list_admin_buildpacks(url_generator, admin_buildpack=nil)

      generator = lambda do |bp|
        {
          key: bp.key,
          url: url_generator.admin_buildpack_download_url(bp)
        }
      end

      if admin_buildpack
        return [generator.call(admin_buildpack)]
      end
      self.all.map do |buildpack|
        generator.call(buildpack)
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