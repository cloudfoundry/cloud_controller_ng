module VCAP::CloudController
  class RouterGroupTypePopulator
    attr_reader :routing_api_client

    def initialize(routing_api_client)
      @routing_api_client = routing_api_client
    end

    def transform(domains, opts={})
      router_groups = routing_api_client.router_groups
      router_group_mapping = {}
      router_groups.each do |router_group|
        router_group_mapping[router_group.guid] = router_group.type
      end
      domains.each { |domain| domain.router_group_type = router_group_mapping[domain.router_group_guid] unless domain.router_group_guid.nil?  }
    # FIXME(crhino) Quick fix until #112941687 is finished
    # We should use the same convention of determining whether the routing api
    # is unavailable as the story above. This would also have the benefit of not
    # requiring an extra HTTP request.
    rescue RoutingApi::Client::RoutingApiUnavailable
    end
  end
end
