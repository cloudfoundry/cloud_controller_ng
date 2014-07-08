module VCAP::CloudController::Diego
  class BuildpackEntryGenerator
    def initialize(blobstore_url_generator)
      @blobstore_url_generator = blobstore_url_generator
    end

    def buildpack_entries(app)
      buildpack = app.buildpack

      if buildpack.instance_of?(VCAP::CloudController::CustomBuildpack)
        if is_zip_format(buildpack)
          return [custom_buildpack_entry(buildpack)]
        else
          return default_admin_buildpacks
        end
      end

      if buildpack.instance_of?(VCAP::CloudController::Buildpack)
        return [admin_buildpack_entry(buildpack)]
      end

      default_admin_buildpacks
    end

    def is_zip_format(buildpack)
      buildpackIsHttp = buildpack.url =~ /^http/
      buildPackIsZip= buildpack.url=~ /\.zip$/
      buildpackIsHttp && buildPackIsZip
    end

    def custom_buildpack_entry(buildpack)
      {name: "custom", key: buildpack.url, url: buildpack.url}
    end

    def default_admin_buildpacks
      VCAP::CloudController::Buildpack.list_admin_buildpacks.
        select(&:enabled).
        collect { |buildpack| admin_buildpack_entry(buildpack) }
    end

    def admin_buildpack_entry(buildpack)
      {
        name: buildpack.name,
        key: buildpack.key,
        url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end
  end
end
