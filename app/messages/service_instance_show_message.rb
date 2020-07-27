module VCAP::CloudController
  class ServiceInstanceShowMessage < BaseMessage
    register_allowed_keys [:fields]

    validates_with NoAdditionalParamsValidator
    validates :fields, allow_nil: true, fields: {
      allowed: {
        'space' => %w(name guid),
        'space.organization' => %w(name guid),
        'service_plan' => %w(name guid),
        'service_plan.service_offering' => %w(name guid description tags documentation_url),
        'service_plan.service_offering.service_broker' => %w(name guid)
      }
    }

    def self.from_params(params)
      instance = super(params, [], fields: %w(fields))
      instance
    end
  end
end
