module VCAP::CloudController
  module Diego
    class DropletUrlGenerator
      def initialize(internal_service_hostname:, tls_port:)
        @internal_service_hostname = internal_service_hostname
        @tls_port                  = tls_port
      end

      attr_reader :internal_service_hostname, :tls_port

      def perma_droplet_download_url(app_guid, droplet_checksum)
        return nil unless droplet_checksum

        URI::HTTPS.build(
          host: internal_service_hostname,
          port: tls_port,
          path: "/internal/v4/droplets/#{app_guid}/#{droplet_checksum}/download"
        ).to_s
      end
    end
  end
end
