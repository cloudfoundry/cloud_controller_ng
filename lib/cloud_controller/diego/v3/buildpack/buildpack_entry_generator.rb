module VCAP::CloudController
  module Diego
    module V3
      module Buildpack
        class BuildpackEntryGenerator
          def initialize(blobstore_url_generator)
            @blobstore_url_generator = blobstore_url_generator
          end

          def buildpack_entries(buildpack_info)
            if buildpack_info.buildpack.nil?
              default_admin_buildpacks
            elsif buildpack_info.buildpack_exists_in_db?
              [admin_buildpack_entry(buildpack_info.buildpack_record).merge(skip_detect: true)]
            elsif buildpack_info.buildpack_url
              [{ name: 'custom', key: buildpack_info.buildpack_url, url: buildpack_info.buildpack_url, skip_detect: true }]
            else
              raise "Unsupported buildpack type: '#{buildpack_info.inspect}'"
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
end
