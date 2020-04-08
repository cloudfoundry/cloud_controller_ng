module VCAP::CloudController
  class ServiceInstanceShowMessage < BaseMessage
    register_allowed_keys [:fields]

    validates_with NoAdditionalParamsValidator
    validates :fields, allow_nil: true, fields: {
      allowed: {
        'space.organization' => ['name', 'guid'],
        'service_plan.service_offering' => ['name', 'guid'],
        'service_plan.service_offering.service_broker' => ['name', 'guid']
      }
    }

    def self.from_params(params)
      instance = super(params, [], fields: %w(fields))
      instance
    end
  end
end
