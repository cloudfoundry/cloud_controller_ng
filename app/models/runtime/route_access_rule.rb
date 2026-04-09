module VCAP::CloudController
  class RouteAccessRule < Sequel::Model(:route_access_rules)
    many_to_one :route,
                class: 'VCAP::CloudController::Route',
                key: :route_id,
                primary_key: :id,
                without_guid_generation: true

    def validate
      validates_presence :name
      validates_presence :selector
      validates_presence :route_id
    end
  end
end
