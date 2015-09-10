module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        class BuildpackEntryGenerator
          def initialize(blobstore_url_generator)
            @blobstore_url_generator = blobstore_url_generator
          end

          def buildpack_entries(buildpack_info)
            return default_admin_buildpacks if buildpack_info.buildpack.nil?

            return [admin_buildpack_entry(buildpack_info.buildpack_record).merge(skip_detect: true)] if buildpack_info.buildpack_exists_in_db?

            return [{ name: 'custom', key: buildpack_info.buildpack_url, url: buildpack_info.buildpack_url }.merge(skip_detect: true)] if buildpack_info.buildpack_url

            raise "Unsupported buildpack type: '#{buildpack_info.inspect}'"
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
end
