module VCAP::CloudController
  class RoutePolicy < Sequel::Model(:route_policies)
    SOURCE_REGEX = /\A(cf:(app|space|org):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|cf:any)\z/
    SERVICE_ACCOUNT_SOURCE_REGEX = /\Acf:svc:([a-z0-9][a-z0-9-]{1,61}[a-z0-9]):([a-z0-9][a-z0-9-]{1,61}[a-z0-9])\z/

    many_to_one :route,
                class: 'VCAP::CloudController::Route',
                key: :route_id,
                primary_key: :id

    one_to_many :labels, class: 'VCAP::CloudController::RoutePolicyLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RoutePolicyAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def source
      if source_type == 'svc'
        account = ServiceAccountModel.first(guid: source_guid)
        return "cf:svc:#{account.identity_prefix}:#{account.name}" if account
      end
      source_guid.to_s.empty? ? 'cf:any' : "cf:#{source_type}:#{source_guid}"
    end

    def source=(val)
      return if val.nil?

      if (identity = val.match(SERVICE_ACCOUNT_SOURCE_REGEX))
        account = ServiceAccountModel.first(identity_prefix: identity[1], name: identity[2])
        self.source_type = 'svc'
        self.source_guid = account&.guid
      elsif val == 'cf:any'
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
      errors.add(:source, 'service account not found') if source_type == 'svc' && source_guid.nil?
      validate_cf_any_exclusivity
    end

    def notify_diego
      return unless route

      route.apps.each do |process|
        ProcessRouteHandler.new(process).notify_backend_of_route_update
      end
    end

    private

    def validate_cf_any_exclusivity
      return unless route_id

      siblings = RoutePolicy.where(route_id: route_id).exclude(id: id)
      return if siblings.empty?

      if source_type == 'any'
        errors.add(:source, "'cf:any' cannot coexist with other route policies on the same route")
      elsif siblings.where(source_type: 'any').any?
        errors.add(:source, "cannot coexist with the existing 'cf:any' policy on this route")
      end
    end
  end
end
