module VCAP::CloudController
  class SharedSpacesShowMessage < BaseMessage
    register_allowed_keys [:fields]

    validates_with NoAdditionalParamsValidator
    validates :fields, allow_nil: true, fields: {
      allowed: {
        'space' => %w[name guid relationships.organization],
        'space.organization' => %w[name guid]
      }
    }

    def self.from_params(params)
      super(params, [], fields: %w[fields])
    end
  end
end
