class RootController < ActionController::Base
  def v3_root
    render :ok, json: MultiJson.dump(
      {
        links: {
          self:  {
            href: build_api_uri
          },
          tasks: {
            href: build_api_uri(path: '/tasks')
          },
          apps: {
            href: build_api_uri(path: '/apps')
          },
          builds: {
            href: build_api_uri(path: '/builds')
          },
          packages: {
            href: build_api_uri(path: '/packages')
          },
          isolation_segments: {
            href: build_api_uri(path: '/isolation_segments')
          },
          organizations: {
            href: build_api_uri(path: '/organizations')
          },
          spaces: {
            href: build_api_uri(path: '/spaces')
          },
          processes: {
            href: build_api_uri(path: '/processes')
          },
          droplets: {
            href: build_api_uri(path: '/droplets')
          }
        }
      }, pretty: true)
  end

  private

  def build_api_uri(path: nil)
    my_uri        = URI::HTTP.build(host: VCAP::CloudController::Config.config.get(:external_domain), path: "/v3#{path}")
    my_uri.scheme = VCAP::CloudController::Config.config.get(:external_protocol)
    my_uri.to_s
  end
end
