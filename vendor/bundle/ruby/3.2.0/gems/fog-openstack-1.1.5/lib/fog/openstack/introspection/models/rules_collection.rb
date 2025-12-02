require 'fog/openstack/models/collection'
require 'fog/openstack/introspection/models/rules'

module Fog
  module OpenStack
    class Introspection
      class RulesCollection < Fog::OpenStack::Collection
        model Fog::OpenStack::Introspection::Rules

        def all(_options = {})
          load_response(service.list_rules, 'rules')
        end

        def get(uuid)
          data = service.get_rules(uuid).body
          new(data)
        rescue Fog::OpenStack::Introspection::NotFound
          nil
        end

        def destroy(uuid)
          rules = get(uuid)
          rules.destroy
        end

        def destroy_all
          service.delete_rules_all
        end
      end
    end
  end
end
