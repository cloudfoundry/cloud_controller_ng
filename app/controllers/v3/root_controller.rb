class RootController < ActionController::Base
  def v3_root
    links = {
      self: {
        href: build_api_uri
      }
    }

    links.merge!(create_link(:app_usage_events))
    links.merge!(create_link(:apps))
    links.merge!(create_link(:audit_events))
    links.merge!(create_link(:buildpacks))
    links.merge!(create_link(:builds))
    links.merge!(create_link(:deployments))
    links.merge!(create_link(:domains))
    links.merge!(create_link(:droplets))
    links.merge!(create_link(:environment_variable_groups))
    links.merge!(create_link(:feature_flags))
    links.merge!(create_link(:info))
    links.merge!(create_link(:isolation_segments))
    links.merge!(create_link(:organizations))
    links.merge!(create_link(:organization_quotas))
    links.merge!(create_link(:packages))
    links.merge!(create_link(:processes))
    links.merge!(create_link(:resource_matches))
    links.merge!(create_link(:roles))
    links.merge!(create_link(:routes))
    links.merge!(create_link(:security_groups))
    links.merge!(create_link(:service_brokers))
    links.merge!(create_link(:service_instances))
    links.merge!(create_link(:service_credential_bindings))
    links.merge!(create_link(:service_offerings))
    links.merge!(create_link(:service_plans))
    links.merge!(create_link(:service_route_bindings))
    links.merge!(create_link(:service_usage_events))
    links.merge!(create_link(:spaces))
    links.merge!(create_link(:space_quotas))
    links.merge!(create_link(:stacks))
    links.merge!(create_link(:tasks))
    links.merge!(create_link(:users))

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
