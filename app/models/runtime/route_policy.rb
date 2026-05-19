module VCAP::CloudController
  class RoutePolicy < Sequel::Model(:route_policies)
    many_to_one :route,
                class: 'VCAP::CloudController::Route',
                key: :route_id,
                primary_key: :id

    one_to_many :labels, class: 'VCAP::CloudController::RoutePolicyLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RoutePolicyAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def validate
      validates_presence :source
      validates_presence :route_id
    end

    def after_create
      super
      notify_processes_of_route_update
    end

    def after_destroy
      super
      notify_processes_of_route_update
    end

    private

    def notify_processes_of_route_update
      return unless route

      db.after_commit do
        route.apps.each do |process|
          ProcessRouteHandler.new(process).notify_backend_of_route_update
        end
      end
    end
  end
end
