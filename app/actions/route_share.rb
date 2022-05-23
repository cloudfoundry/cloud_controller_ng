require 'repositories/route_event_repository'

module VCAP::CloudController
  class RouteShare
    class Error < ::StandardError
    end

    def create(route, target_spaces, user_audit_info)
      validate_not_sharing_to_self!(route, target_spaces)

      Route.db.transaction do
        target_spaces.each do |space|
          route.add_shared_space(space)
        end
      end
      Repositories::RouteEventRepository.new.record_route_share(
        route, user_audit_info, target_spaces.map(&:guid)
      )
      route
    end

    private

    def error!(message)
      raise Error.new(message)
    end

    def validate_not_sharing_to_self!(route, spaces)
      if spaces.include?(route.space)
        error!("Unable to share route '#{route.uri}' with space '#{route.space.guid}'. Routes cannot be shared into the space where they were created.")
      end
    end
  end
end
