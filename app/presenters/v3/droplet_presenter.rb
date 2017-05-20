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
            links.merge!(links_for_lifecyle(url_builder))
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
          return nil unless droplet.buildpack_receipt_buildpack

          [{
            name:          CloudController::UrlSecretObfuscator.obfuscate(droplet.buildpack_receipt_buildpack),
            detect_output: droplet.buildpack_receipt_detect_output
          }]
        end

        def links_for_lifecyle(url_builder)
          links = {}

          if droplet.lifecycle_type == Lifecycles::BUILDPACK
            if droplet.buildpack_receipt_buildpack_guid
              links[:buildpack] = { href: url_builder.build_url(path: "/v2/buildpacks/#{droplet.buildpack_receipt_buildpack_guid}") }
            end
          end

          links
        end
      end
    end
  end
end
