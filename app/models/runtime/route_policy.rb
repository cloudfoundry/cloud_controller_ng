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

    def source
      source_guid.to_s.empty? ? 'cf:any' : "cf:#{source_type}:#{source_guid}"
    end

    def source=(val)
      return if val.nil?

      if val == 'cf:any'
        self.source_type = 'any'
        self.source_guid = ''
      else
        m = val.match(/\Acf:(app|space|org):([0-9a-f-]+)\z/)
        self.source_type = m ? m[1] : nil
        self.source_guid = m ? m[2] : nil
      end
    end

    def validate
      validates_presence :source_type
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
