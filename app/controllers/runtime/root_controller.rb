require 'presenters/api_url_builder'

module VCAP::CloudController
  class RootController < RestController::BaseController
    allow_unauthenticated_access

    get '/', :read

    def read
      api_url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

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

          uaa: {
            href: VCAP::CloudController::Config.config[:uaa][:url]
          },

          logging: {
            href: VCAP::CloudController::Config.config[:doppler][:url]
          }
        }
      }

      [200, MultiJson.dump(response, pretty: true)]
    end
  end
end
