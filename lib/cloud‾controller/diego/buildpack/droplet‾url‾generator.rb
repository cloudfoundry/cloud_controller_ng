module VCAP::CloudController
  module Diego
    module Buildpack
      class DropletUrlGenerator
        def initialize(internal_service_hostname:, external_port:, tls_port:, mtls:)
          @internal_service_hostname = internal_service_hostname
          @external_port             = external_port
          @tls_port                  = tls_port
          @mtls                      = mtls
        end

        attr_reader :internal_service_hostname, :external_port, :tls_port, :mtls

        def perma_droplet_download_url(app_guid, droplet_checksum)
          return nil unless droplet_checksum

          if mtls
            build_https_url(app_guid, droplet_checksum)
          else
            build_http_url(app_guid, droplet_checksum)
          end
        end

        private

        def build_https_url(guid, droplet_checksum)
          URI::HTTPS.build(
            host: internal_service_hostname,
            port: tls_port,
            path: "/internal/v4/droplets/#{guid}/#{droplet_checksum}/download",
          ).to_s
        end

        def build_http_url(guid, droplet_checksum)
          URI::HTTP.build(
            host: internal_service_hostname,
            port: external_port,
            path: "/internal/v2/droplets/#{guid}/#{droplet_checksum}/download",
          ).to_s
        end
      end
    end
  end
end
