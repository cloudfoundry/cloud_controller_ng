module VCAP
  module CloudController
    class RouteBindingListFetcher
      def fetch_all(message)
        filter(message, all_bindings).
          select_all(:route_bindings)
      end

      def fetch_some(message, space_guids:)
        bindings = all_bindings.
                   join(:spaces, id: Sequel[:service_instances][:space_id]).
                   where { Sequel[:spaces][:guid] =~ space_guids }

        filter(message, bindings).
          select_all(:route_bindings)
      end

      private

      def all_bindings
        RouteBinding.dataset.
          join(:service_instances, id: Sequel[:route_bindings][:service_instance_id]).
          join(:routes, id: Sequel[:route_bindings][:route_id])
      end

      def filter(message, bindings)
        filtered_bindings = bindings

        if message.requested?(:service_instance_guids)
          filtered_bindings = filtered_bindings.where { Sequel[:service_instances][:guid] =~ message.service_instance_guids }
        end

        if message.requested?(:route_guids)
          filtered_bindings = filtered_bindings.where { Sequel[:routes][:guid] =~ message.route_guids }
        end

        filtered_bindings
      end
    end
  end
end
