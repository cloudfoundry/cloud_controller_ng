require 'repositories/route_policy_event_repository'

module VCAP::CloudController
  class RoutePolicyCreate
    class Error < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(route:, message:)
      validate_scope!(route.domain, message.source)

      route_policy = RoutePolicy.db.transaction do
        # Lock the parent route row to serialize concurrent creates.
        # SELECT ... FOR UPDATE on an empty policies table acquires no row locks,
        # so two concurrent transactions can both read [] and both pass cf:any
        # exclusivity validation. Locking the route row (which always exists)
        # ensures they serialize regardless of how many policies currently exist.
        Route.where(id: route.id).for_update.first or raise Error.new("Route '#{route.guid}' not found.")

        RoutePolicy.create(
          source: message.source,
          route_id: route.id
        )
      end

      route_policy.notify_diego

      Repositories::RoutePolicyEventRepository.new.record_route_policy_create(
        route_policy,
        @user_audit_info,
        { 'source' => message.source, 'route_guid' => route.guid }
      )

      route_policy
    rescue Sequel::UniqueConstraintViolation
      raise Error.new("A route policy with source '#{message.source}' already exists for this route.")
    rescue Sequel::ValidationFailed => e
      raise Error.new(e.errors.full_messages.join(', '))
    end

    private

    def validate_scope!(domain, source)
      return unless domain.route_policies_scope == 'space'
      return unless source.start_with?('cf:org:')

      raise Error.new("Source '#{source}' is not allowed: domain's route_policies_scope is 'space'.")
    end
  end
end
