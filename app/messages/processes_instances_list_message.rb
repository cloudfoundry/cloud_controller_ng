require 'messages/list_message'

module VCAP::CloudController
  class ProcessesInstancesListMessage < ListMessage
    register_allowed_keys %i[
      process_guids
      app_guids
      space_guids
      organization_guids
    ]

    # Exclude :guids from allowed keys in ListMessage. Instead, :process_guids is used to filter processes instances.
    const_set(:ALLOWED_KEYS, (self.allowed_keys - [:guids]).freeze)

    validates_with NoAdditionalParamsValidator

    validates :process_guids, array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w[process_guids app_guids space_guids organization_guids])
    end
  end
end
