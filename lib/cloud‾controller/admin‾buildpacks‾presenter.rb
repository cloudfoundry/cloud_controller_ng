require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  class AdminBuildpacksPresenter
    def self.enabled_buildpacks
      new.enabled
    end

    def enabled
      Buildpack.list_admin_buildpacks.
        select(&:enabled).
        collect { |buildpack| admin_buildpack_entry(buildpack) }.
        select { |entry| entry[:url] }
    end

    private

    def admin_buildpack_entry(buildpack)
      {
        key: buildpack.key,
        url: blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end

    def blobstore_url_generator
      @blobstore_url_generator ||= CloudController::DependencyLocator.instance.blobstore_url_generator
    end
  end
end
