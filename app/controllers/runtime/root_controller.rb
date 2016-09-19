module VCAP::CloudController
  class RootController < RestController::BaseController
    allow_unauthenticated_access

    get '/', :read

    def read
      response = {
        links: {
          self: {
            href: build_api_uri
          },

          cloud_controller_v2: {
            href: build_api_uri(path: '/v2'),
            meta: {
              version: VCAP::CloudController::Constants::API_VERSION
            }
          },

          cloud_controller_v3: {
            href: build_api_uri(path: '/v3'),
            meta: {
              version: VCAP::CloudController::Constants::API_VERSION_V3
            }
          }
        }
      }

      [200, MultiJson.dump(response, pretty: true)]
    end

    private

    def build_api_uri(path: nil)
      my_uri = URI::HTTP.build(host: Config.config[:external_domain], path: path)
      my_uri.scheme = Config.config[:external_protocol]
      my_uri.to_s
    end
  end
end
