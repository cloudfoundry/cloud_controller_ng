module VCAP::CloudController
  class Buildpack < Sequel::Model

    export_attributes :name, :key, :priority

    import_attributes :name, :key, :priority

    def self.list_admin_buildpacks
      blob_store = CloudController::DependencyLocator.instance.buildpack_blobstore
      self.all.map do |buildpack|
        {
          key: buildpack.key,
          url: blob_store.download_uri(buildpack.key)
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