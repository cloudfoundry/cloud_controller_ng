class RootController < ActionController::Base
  def v3_root
    render :ok, json: MultiJson.dump(
      {
        links: {
          self:  {
            href: build_api_uri
          },
          apps: {
            href: build_api_uri(path: '/apps')
          },
          buildpacks: {
            href: build_api_uri(path: '/buildpacks'),
            experimental: true,
          },
          builds: {
            href: build_api_uri(path: '/builds')
          },
          deployments: {
            href: build_api_uri(path: '/deployments'),
            experimental: true,
          },
          droplets: {
            href: build_api_uri(path: '/droplets')
          },
          feature_flags: {
            href: build_api_uri(path: '/feature_flags'),
            experimental: true,
          },
          isolation_segments: {
            href: build_api_uri(path: '/isolation_segments')
          },
          organizations: {
            href: build_api_uri(path: '/organizations')
          },
          packages: {
            href: build_api_uri(path: '/packages')
          },
          processes: {
            href: build_api_uri(path: '/processes')
          },
          service_instances: {
            href: build_api_uri(path: '/service_instances')
          },
          spaces: {
            href: build_api_uri(path: '/spaces')
          },
          stacks: {
            href: build_api_uri(path: '/stacks')
          },
          tasks: {
            href: build_api_uri(path: '/tasks')
          },
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
