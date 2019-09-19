class RootController < ActionController::Base
  def v3_root
    links = {
      self: {
        href: build_api_uri
      }
    }

    links.merge!(create_link(:apps))
    links.merge!(create_link(:buildpacks))
    links.merge!(create_link(:builds))
    links.merge!(create_link(:deployments, experimental: true))
    links.merge!(create_link(:domains))
    links.merge!(create_link(:droplets))
    links.merge!(create_link(:feature_flags))
    links.merge!(create_link(:isolation_segments))
    links.merge!(create_link(:organizations))
    links.merge!(create_link(:packages))
    links.merge!(create_link(:processes))
    links.merge!(create_link(:resource_matches, experimental: true))
    links.merge!(create_link(:roles, experimental: true))
    links.merge!(create_link(:routes))
    links.merge!(create_link(:service_brokers, experimental: true))
    links.merge!(create_link(:service_instances))
    links.merge!(create_link(:spaces))
    links.merge!(create_link(:stacks))
    links.merge!(create_link(:tasks))
    links.merge!(create_link(:users, experimental: true))

    render :ok, json: MultiJson.dump({ links: links }, pretty: true)
  end

  private

  def create_link(key, experimental: false)
    obj = { key => { href: build_api_uri(path: "/#{key}") } }
    obj[key][:experimental] = true if experimental
    obj
  end

  def build_api_uri(path: nil)
    my_uri = URI::HTTP.build(host: VCAP::CloudController::Config.config.get(:external_domain), path: "/v3#{path}")
    my_uri.scheme = VCAP::CloudController::Config.config.get(:external_protocol)
    my_uri.to_s
  end
end
