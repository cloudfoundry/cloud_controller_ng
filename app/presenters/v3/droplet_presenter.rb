require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class DropletPresenter < BasePresenter
        def to_hash
          {
            guid:               droplet.guid,
            state:              droplet.state,
            error:              droplet.error,
            lifecycle:          {
              type: droplet.lifecycle_type,
              data: {},
            },
            checksum:           droplet_checksum_info,
            buildpacks:         droplet_buildpack_info,
            stack:              droplet.lifecycle_data.try(:stack),
            image:              droplet.docker_receipt_image,
            execution_metadata: redact(droplet.execution_metadata),
            process_types:      redact_hash(droplet.process_types),
            created_at:         droplet.created_at,
            updated_at:         droplet.updated_at,
            links:              build_links,
          }
        end

        private

        def droplet
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self:                   { href: url_builder.build_url(path: "/v3/droplets/#{droplet.guid}") },
            package:                nil,
            app:                    { href: url_builder.build_url(path: "/v3/apps/#{droplet.app_guid}") },
            assign_current_droplet: { href: url_builder.build_url(path: "/v3/apps/#{droplet.app_guid}/relationships/current_droplet"), method: 'PATCH' },
          }.tap do |links|
            links[:package] = { href: url_builder.build_url(path: "/v3/packages/#{droplet.package_guid}") } if droplet.package_guid.present?
          end
        end

        def droplet_checksum_info
          if droplet.sha256_checksum
            { type: 'sha256', value: droplet.sha256_checksum }
          elsif droplet.droplet_hash
            { type: 'sha1', value: droplet.droplet_hash }
          end
        end

        def droplet_buildpack_info
          return nil unless droplet.buildpack_lifecycle_data&.buildpack_lifecycle_buildpacks
          droplet.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks.map do |buildpack|
            if buildpack.admin_buildpack_name
              name_to_lookup = name_to_print = buildpack.admin_buildpack_name
            else
              name_to_lookup = buildpack.buildpack_url
              name_to_print = CloudController::UrlSecretObfuscator.obfuscate(buildpack.buildpack_url)
            end
            detect_output = droplet.buildpack_receipt_buildpack&.==(name_to_lookup) ? droplet.buildpack_receipt_detect_output : nil
            {
              name: name_to_print,
              detect_output: detect_output,
              buildpack_name: buildpack.buildpack_name,
              version: buildpack.version
            }
          end
        end
      end
    end
  end
end
