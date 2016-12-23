module CloudController
  module Presenters
    module V2
      class ServiceInstancePresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServiceInstance'
        present_for_class 'VCAP::CloudController::ManagedServiceInstance'
        present_for_class 'VCAP::CloudController::UserProvidedServiceInstance'

        def entity_hash(controller, obj, opts, depth, parents, orphans=nil)
          export_attrs = opts.delete(:export_attrs) if depth.zero?

          rel_hash = RelationsPresenter.new.to_hash(controller, obj, opts, depth, parents, orphans)
          obj_hash = obj.to_hash(attrs: export_attrs)

          if obj.export_attrs_from_methods
            obj.export_attrs_from_methods.each do |key, meth|
              obj_hash[key.to_s] = obj.send(meth)
            end
          end

          if obj.service_plan_id
            service_plan = VCAP::CloudController::ServicePlan.find(id: obj.service_plan_id)
            obj_hash['service_plan_guid'] = service_plan.guid
            obj_hash['service_guid'] = service_plan.service.guid
            rel_hash['service_url'] = "/v2/services/#{service_plan.service.guid}"
          end

          obj_hash.merge!(rel_hash)
        end
      end
    end
  end
end
