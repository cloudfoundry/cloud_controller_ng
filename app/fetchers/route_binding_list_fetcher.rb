module VCAP
  module CloudController
    class RouteBindingListFetcher
      def fetch_all
        RouteBinding.dataset
      end

      def fetch_some(space_guids:)
        RouteBinding.dataset.
          join(:service_instances, id: Sequel[:route_bindings][:service_instance_id]).
          join(:spaces, id: Sequel[:service_instances][:space_id]).
          where { Sequel[:spaces][:guid] =~ space_guids }.
          select_all(:route_bindings)
      end
    end
  end
end
