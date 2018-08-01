module VCAP::CloudController
  class RouterGroupTypePopulator
    attr_reader :routing_api_client

    def initialize(routing_api_client)
      @routing_api_client = routing_api_client
    end

    def transform(domains, opts={})
      return domains unless routing_api_client.enabled?
      return domains if domains.select { |d| d.router_group_guid.present? }.blank?
      router_groups = routing_api_client.router_groups
      router_group_mapping = {}
      router_groups.each do |router_group|
        router_group_mapping[router_group.guid] = router_group.type
      end
      domains.each { |domain| domain.router_group_type = router_group_mapping[domain.router_group_guid] }
    end
  end
end
