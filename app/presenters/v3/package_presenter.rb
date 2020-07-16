require 'presenters/v3/base_presenter'
require 'presenters/helpers/censorship'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class PackagePresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def initialize(
          resource,
          show_secrets: false,
          censored_message: Censorship::REDACTED_CREDENTIAL,
          show_bits_service_upload_link: false
        )
          @show_bits_service_upload_link = show_bits_service_upload_link

          super(resource, show_secrets: show_secrets, censored_message: censored_message)
        end

        def to_hash
          {
            guid:       package.guid,
            created_at: package.created_at,
            updated_at: package.updated_at,
            type:       package.type,
            data:       build_data,
            state:      package.state,
            relationships: { app: { data: { guid: package.app_guid } } },
            metadata: {
              labels: hashified_labels(package.labels),
              annotations: hashified_annotations(package.annotations),
            },
            links:      build_links,
          }
        end

        private

        def package
          @resource
        end

        def build_data
          package.docker? ? docker_data : buildpack_data
        end

        def docker_data
          {
            image: package.image,
            username: package.docker_username,
            password: package.docker_username && Censorship::REDACTED_CREDENTIAL,
          }
        end

        def buildpack_data
          {
            error: package.error,
            checksum:  package.checksum_info,
          }
        end

        def build_links
          upload_link   = nil
          download_link = nil
          if package.type == 'bits'
            upload_link = if VCAP::CloudController::Config.config.get(:bits_service, :enabled)
                            bits_service_upload_link
                          else
                            { href: url_builder.build_url(path: "/v3/packages/#{package.guid}/upload"), method: 'POST' }
                          end

            download_link = { href: url_builder.build_url(path: "/v3/packages/#{package.guid}/download") }
          end

          links = {
            self:     { href: url_builder.build_url(path: "/v3/packages/#{package.guid}") },
            upload:   upload_link,
            download: download_link,
            app:      { href: url_builder.build_url(path: "/v3/apps/#{package.app_guid}") },
          }

          links.delete_if { |_, v| v.nil? }
        end

        def bits_service_upload_link
          return nil unless @show_bits_service_upload_link

          { href: bits_service_client.blob(package.guid).public_upload_url, method: 'PUT' }
        end

        def bits_service_client
          CloudController::DependencyLocator.instance.package_blobstore
        end
      end
    end
  end
end
