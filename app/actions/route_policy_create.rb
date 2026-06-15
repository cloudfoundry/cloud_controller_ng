module VCAP::CloudController
  class RoutePolicyCreate
    class Error < StandardError
    end

    def create(route:, message:)
      RoutePolicy.db.transaction do
        # Lock the parent route row to serialize concurrent creates.
        # SELECT ... FOR UPDATE on an empty policies table acquires no row locks,
        # so two concurrent transactions can both read [] and both pass cf:any
        # exclusivity validation. Locking the route row (which always exists)
        # ensures they serialize regardless of how many policies currently exist.
        Route.where(id: route.id).for_update.first

        existing_policies = RoutePolicy.where(route_id: route.id).all
        validate_source_exclusivity(existing_policies, message.source)

        RoutePolicy.create(
          source: message.source,
          route_id: route.id
        )
      end
    rescue Sequel::UniqueConstraintViolation
      raise Error.new("A route policy with source '#{message.source}' already exists for this route.")
    end

    private

    def validate_source_exclusivity(locked_policies, source)
      existing_sources = locked_policies.map(&:source)

      # Enforce cf:any exclusivity: if new policy is cf:any, reject if route already has any policies;
      # if route already has a cf:any policy, reject new policies.
      raise Error.new("Cannot add 'cf:any' source when other route policies already exist for this route.") if source == 'cf:any' && existing_sources.any?
      raise Error.new("Cannot add source '#{source}': route already has a 'cf:any' policy.") if existing_sources.include?('cf:any')
    end
  end
end
