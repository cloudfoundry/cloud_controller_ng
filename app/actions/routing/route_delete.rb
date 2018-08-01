module VCAP::CloudController
  class RouteDelete
    class ServiceInstanceAssociationError < StandardError; end

    def initialize(app_event_repository:, route_event_repository:, user:, user_email:)
      @app_event_repository   = app_event_repository
      @route_event_repository = route_event_repository
      @user                   = user
      @user_email             = user_email
    end

    def delete_sync(route:, recursive:)
      deletion_job = do_delete(recursive, route)
      deletion_job.perform
    end

    def delete_async(route:, recursive:)
      deletion_job = do_delete(recursive, route)
      Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue
    end

    private

    def do_delete(recursive, route)
      if !recursive && route.service_instance.present?
        raise ServiceInstanceAssociationError.new
      end

      route_event_repository.record_route_delete_request(
        route,
        user,
        user_email,
        recursive
      )

      route.route_mappings.each do |route_mapping|
        app_event_repository.record_unmap_route(
          route_mapping.app,
          route,
          user.guid,
          user_email,
          route_mapping: route_mapping
        )
      end

      Jobs::Runtime::ModelDeletion.new(route.class, route.guid)
    end

    attr_reader :route_event_repository, :app_event_repository, :user, :user_email
  end
end
