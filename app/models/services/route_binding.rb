require 'cloud_controller/process_route_handler'
require 'models/runtime/helpers/service_operation_mixin'

module VCAP::CloudController
  class RouteBinding < Sequel::Model
    include ServiceOperationMixin

    plugin :after_initialize

    one_to_one :route_binding_operation

    one_to_many :labels, class: 'VCAP::CloudController::RouteBindingLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RouteBindingAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    many_to_one :route
    many_to_one :service_instance

    export_attributes :route_service_url

    import_attributes :route_service_url

    delegate :service, :service_plan, :client, to: :service_instance

    def notify_diego
      route.apps.each do |process|
        ProcessRouteHandler.new(process).notify_backend_of_route_update
      end
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def validate
      validates_presence :service_instance
      validates_presence :route
      validate_routing_service
      validate_space_match
    end

    def last_operation
      route_binding_operation
    end

    def save_with_attributes_and_new_operation(attributes, operation)
      save_with_new_operation(attributes, operation)
    end

    def save_with_new_operation(attributes, new_operation)
      RouteBinding.db.transaction do
        self.lock!
        set(attributes)
        save_changes

        if self.last_operation
          self.last_operation.destroy
        end

        # it is important to create the service route binding operation with the service binding
        # instead of doing self.service_route_binding_operation = x
        # because mysql will deadlock when requests happen concurrently otherwise.
        RouteBindingOperation.create(new_operation.merge(route_binding_id: self.id))
        self.route_binding_operation(reload: true)
      end

      self
    end

    private

    def validate_routing_service
      return unless service_instance

      unless service_instance.route_service?
        errors.add(:service_instance, :route_binding_not_allowed)
      end
    end

    def validate_space_match
      return unless service_instance && route

      unless service_instance.space == route.space
        errors.add(:service_instance, :space_mismatch)
      end
    end
  end
end
