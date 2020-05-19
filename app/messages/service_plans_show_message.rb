module VCAP::CloudController
  class ServicePlansShowMessage < BaseMessage
    @array_keys = [
      :include
    ]
    @single_keys = [
      :fields
    ]

    register_allowed_keys(@single_keys + @array_keys)

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w(space.organization service_offering)
    validates :fields, allow_nil: true, fields: {
      allowed: {
        'service_offering.service_broker' => ['guid', 'name']
      }
    }

    def self.from_params(params)
      super(params, @array_keys.map(&:to_s), fields: %w(fields))
    end
  end
end
