require 'presenters/api_url_builder'

module VCAP::CloudController
  class RootController < RestController::BaseController
    allow_unauthenticated_access

    get '/', :read

    def read
      api_url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder

      response = {
        links: {
          self: {
            href: api_url_builder.build_url
          },

          cloud_controller_v2: {
            href: api_url_builder.build_url(path: '/v2'),
            meta: {
              version: VCAP::CloudController::Constants::API_VERSION
            }
          },

          cloud_controller_v3: {
            href: api_url_builder.build_url(path: '/v3'),
            meta: {
              version: VCAP::CloudController::Constants::API_VERSION_V3
            }
          },

          network_policy_v0: {
            href: api_url_builder.build_url(path: '/networking/v0/external'),
          },

          network_policy_v1: {
            href: api_url_builder.build_url(path: '/networking/v1/external'),
          },

          login: {
            href: config.get(:login, :url)
          },

          uaa: {
            href: config.get(:uaa, :url)
          },

          credhub: credhub_link,
          routing: routing_link,

          logging: {
            href: config.get(:doppler, :url)
          },

          log_cache: {
            href: config.get(:log_cache, :url)
          },

          log_stream: {
            href: config.get(:log_stream, :url)
          },

          app_ssh: {
            href: config.get(:info, :app_ssh_endpoint),
            meta: {
              host_key_fingerprint: config.get(:info, :app_ssh_host_key_fingerprint),
              oauth_client: config.get(:info, :app_ssh_oauth_client)
            }
          },

        }
      }

      [200, MultiJson.dump(response, pretty: true)]
    end

    private

    def config
      VCAP::CloudController::Config.config
    end

    def credhub_link
      return unless config.get(:credhub_api, :external_url).present?

      { href: config.get(:credhub_api, :external_url) }
    end

    def routing_link
      return unless config.get(:routing_api).present?

      { href: config.get(:routing_api, :url) }
    end
  end
end
