module VCAP::CloudController
  class AdminBuildpacksPresenter
    def initialize(blobstore_url_generator, buildpack_blobstore)
      @blobstore_url_generator = blobstore_url_generator
      @buildpack_blobstore = buildpack_blobstore
      @blobcache = {}
    end

    def to_staging_message_array
      buildpacks = Buildpack.list_admin_buildpacks.
        select(&:enabled)

      new_cache = {}
      entries = buildpacks.inject([]) do |array, buildpack|
        entry = admin_buildpack_entry(buildpack)
        if entry[:blob]
          new_cache[buildpack.key] = entry
          array << {
            key: buildpack.key,
            url: @blobstore_url_generator.admin_buildpack_blob_download_url(entry[:blob], entry[:guid])
          }
        end
        array
      end
      @blobcache = new_cache
      entries
    end

    private

    def admin_buildpack_entry(buildpack)
      @blobcache[buildpack.key] || {
        guid: buildpack.guid,
        blob: @buildpack_blobstore.blob(buildpack.key)
      }
    end
  end
end
