require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class PackagePresenter < BasePresenter
        def to_hash
          {
            guid:       package.guid,
            type:       package.type,
            data:       build_data,
            state:      package.state,
            created_at: package.created_at,
            updated_at: package.updated_at,
            links:      build_links,
          }
        end

        private

        def package
          @resource
        end

        DEFAULT_HASHING_ALGORITHM = 'sha1'.freeze

        def build_data
          package.docker? ? docker_data : buildpack_data
        end

        def docker_data
          {
            image: package.image,
          }
        end

        def buildpack_data
          {
            error: package.error,
            hash:  {
              type:  DEFAULT_HASHING_ALGORITHM,
              value: package.package_hash
            },
          }
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          upload_link = nil
          download_link = nil
          if package.type == 'bits'
            upload_link   = { href: url_builder.build_url(path: "/v3/packages/#{package.guid}/upload"), method: 'POST' }
            download_link = { href: url_builder.build_url(path: "/v3/packages/#{package.guid}/download"), method: 'GET' }
          end

          links = {
            self: { href: url_builder.build_url(path: "/v3/packages/#{package.guid}") },
            upload: upload_link,
            download: download_link,
            stage: { href: url_builder.build_url(path: "/v3/packages/#{package.guid}/droplets"), method: 'POST' },
            app: { href: url_builder.build_url(path: "/v3/apps/#{package.app_guid}") },
          }

          links.delete_if { |_, v| v.nil? }
        end
      end
    end
  end
end
