module VCAP::CloudController
  class RoutePolicyCreate
    class Error < StandardError
    end

    def create(route:, message:)
      RoutePolicy.db.transaction do
        # Lock existing route policies for this route to prevent concurrent inserts
        # from violating cf:any exclusivity or uniqueness constraints
        locked_policies = RoutePolicy.where(route_id: route.id).for_update.all

        validate_source_exclusivity(locked_policies, message.source)

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
