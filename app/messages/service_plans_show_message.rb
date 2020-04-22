module VCAP::CloudController
  class ServicePlansShowMessage < BaseMessage
    register_allowed_keys [:fields]

    validates_with NoAdditionalParamsValidator
    validates :fields, allow_nil: true, fields: {
      allowed: {
        'service_offering.service_broker' => ['guid', 'name']
      }
    }

    def self.from_params(params)
      super(params, [], fields: %w(fields))
    end
  end
end
