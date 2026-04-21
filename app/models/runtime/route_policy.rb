module VCAP::CloudController
  class RoutePolicy < Sequel::Model(:route_policies)
    many_to_one :route,
                class: 'VCAP::CloudController::Route',
                key: :route_id,
                primary_key: :id,
                without_guid_generation: true

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
      touch_associated_processes
    end

    def after_destroy
      super
      touch_associated_processes
    end

    private

    def touch_associated_processes
      # Update the timestamp on all processes associated with this route
      # This triggers Diego's ProcessesSync to pick up the route changes
      return unless route

      route.apps.each do |process|
        process.update(updated_at: Time.now)
      end
    end
  end
end
