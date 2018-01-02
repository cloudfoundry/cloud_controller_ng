module VCAP::CloudController
  module Diego
    module Buildpack
      class BuildpackEntryGenerator
        def initialize(blobstore_url_generator)
          @blobstore_url_generator = blobstore_url_generator
        end

        def buildpack_entries(buildpack_infos, stack_name)
          return default_admin_buildpacks(stack_name) if buildpack_infos.empty?

          buildpack_infos.map do |buildpack_info|
            if buildpack_info.buildpack_exists_in_db? && buildpack_info.buildpack_enabled?
              admin_buildpack_entry(buildpack_info.buildpack_record).merge(skip_detect: true)
            elsif buildpack_info.buildpack_url
              { name: 'custom', key: buildpack_info.buildpack_url, url: buildpack_info.buildpack_url, skip_detect: true }
            else
              raise "Unsupported buildpack type: '#{buildpack_info.buildpack}'"
            end
          end
        end

        private

        def custom_buildpack_entry(buildpack)
          { name: 'custom', key: buildpack.url, url: buildpack.url }
        end

        def default_admin_buildpacks(stack_name)
          VCAP::CloudController::Buildpack.list_admin_buildpacks(stack_name).
            select(&:enabled).
            collect { |buildpack| admin_buildpack_entry(buildpack) }
        end

        def admin_buildpack_entry(buildpack)
          {
            name:   buildpack.name,
            key:    buildpack.key,
            sha256: buildpack.sha256_checksum,
            url:    @blobstore_url_generator.admin_buildpack_download_url(buildpack),
            skip_detect: false,
          }
        end
      end
    end
  end
end
