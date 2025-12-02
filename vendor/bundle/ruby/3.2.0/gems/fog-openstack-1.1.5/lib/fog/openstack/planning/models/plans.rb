require 'fog/openstack/models/collection'
require 'fog/openstack/planning/models/plan'

module Fog
  module OpenStack
    class Planning
      class Plans < Fog::OpenStack::Collection
        model Fog::OpenStack::Planning::Plan

        def all(options = {})
          load_response(service.list_plans(options))
        end

        def find_by_uuid(plan_uuid)
          new(service.get_plan(plan_uuid).body)
        end
        alias get find_by_uuid

        def method_missing(method_sym, *arguments, &block)
          if method_sym.to_s =~ /^find_by_(.*)$/
            all.find do |plan|
              plan.send($1) == arguments.first
            end
          else
            super
          end
        end
      end
    end
  end
end
