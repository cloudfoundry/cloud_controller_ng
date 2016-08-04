require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class DropletPresenter < BasePresenter
        def to_hash
          {
            guid:                  droplet.guid,
            state:                 droplet.state,
            error:                 droplet.error,
            lifecycle:             {
              type: droplet.lifecycle_type,
              data: droplet.lifecycle_data.as_json
            },
            staging_memory_in_mb:  droplet.staging_memory_in_mb,
            staging_disk_in_mb:    droplet.staging_disk_in_mb,
            result:                result_for_lifecycle,
            environment_variables: redact_hash(droplet.environment_variables || {}),
            created_at:            droplet.created_at,
            updated_at:            droplet.updated_at,
            links:                 build_links,
          }
        end

        private

        def droplet
          @resource
        end

        DEFAULT_HASHING_ALGORITHM = 'sha1'.freeze

        def build_links
          {
            self:                   { href: "/v3/droplets/#{droplet.guid}" },
            package:                nil,
            app:                    { href: "/v3/apps/#{droplet.app_guid}" },
            assign_current_droplet: { href: "/v3/apps/#{droplet.app_guid}/droplets/current", method: 'PUT' },
          }.tap do |links|
            links[:package] = { href: "/v3/packages/#{droplet.package_guid}" } if droplet.package_guid.present?
            links.merge!(links_for_lifecyle)
          end
        end

        def result_for_lifecycle
          return nil unless DropletModel::COMPLETED_STATES.include?(droplet.state)

          lifecycle_result = if droplet.lifecycle_type == Lifecycles::BUILDPACK
                               {
                                 hash:
                                 {
                                 type:  DEFAULT_HASHING_ALGORITHM,
                                 value: droplet.droplet_hash,
                               },
                                 buildpack: droplet.buildpack_receipt_buildpack,
                                 stack:     droplet.buildpack_receipt_stack_name,
                               }
                             elsif droplet.lifecycle_type == Lifecycles::DOCKER
                               {
                                 image: droplet.docker_receipt_image
                               }
                             end

          {
            execution_metadata: redact(droplet.execution_metadata),
            process_types:      redact_hash(droplet.process_types)
          }.merge(lifecycle_result)
        end

        def links_for_lifecyle
          links = {}

          if droplet.lifecycle_type == Lifecycles::BUILDPACK
            if droplet.buildpack_receipt_buildpack_guid
              links[:buildpack] = { href: "/v2/buildpacks/#{droplet.buildpack_receipt_buildpack_guid}" }
            end
          end

          links
        end
      end
    end
  end
end
