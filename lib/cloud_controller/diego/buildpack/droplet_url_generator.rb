module VCAP::CloudController
  module Diego
    module Buildpack
      class DropletUrlGenerator
        def initialize(config=Config.config)
          @config = config
        end

        def perma_droplet_download_url(app)
          return nil unless app.droplet_hash

          URI::HTTP.build(
            host: @config[:internal_service_hostname],
            port: @config[:external_port],
            path: "/internal/v2/droplets/#{app.guid}/#{app.droplet_checksum}/download",
          ).to_s
        end
      end
    end
  end
end
