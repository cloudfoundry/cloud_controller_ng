module VCAP::CloudController
  module Diego
    module Buildpack
      class BuildpackEntryGenerator
        def initialize(blobstore_url_generator)
          @blobstore_url_generator = blobstore_url_generator
        end

        def buildpack_entries(app)
          buildpack = app.buildpack

          case buildpack
          when VCAP::CloudController::CustomBuildpack
            [custom_buildpack_entry(buildpack).merge(skip_detect: true)]
          when VCAP::CloudController::Buildpack
            [admin_buildpack_entry(buildpack).merge(skip_detect: true)]
          when VCAP::CloudController::AutoDetectionBuildpack
            default_admin_buildpacks
          else
            raise "Unsupported buildpack type: '#{buildpack.class}'"
          end
        end

        private

        def custom_buildpack_entry(buildpack)
          { name: 'custom', key: buildpack.url, url: buildpack.url }
        end

        def default_admin_buildpacks
          VCAP::CloudController::Buildpack.list_admin_buildpacks.
            select(&:enabled).
            collect { |buildpack| admin_buildpack_entry(buildpack) }
        end

        def admin_buildpack_entry(buildpack)
          {
            name: buildpack.name,
            key:  buildpack.key,
            url:  @blobstore_url_generator.admin_buildpack_download_url(buildpack)
          }
        end
      end
    end
  end
end
