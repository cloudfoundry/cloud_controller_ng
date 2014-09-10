module VCAP::CloudController
  class AdminBuildpacksPresenter
    def initialize(blobstore_url_generator)
      @blobstore_url_generator = blobstore_url_generator
    end

    def to_staging_message_array
      Buildpack.list_admin_buildpacks.
        select(&:enabled).
        collect { |buildpack| admin_buildpack_entry(buildpack) }.
        select { |entry| entry[:url] }
    end

    def admin_buildpack_entry(buildpack)
      {
        key: buildpack.key,
        url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end
  end
end
