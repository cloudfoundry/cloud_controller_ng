require 'messages/list_message'

module VCAP::CloudController
  class SecurityGroupListMessage < ListMessage
    register_allowed_keys [:guids, :names, :running_space_guids, :staging_space_guids, :globally_enabled_running, :globally_enabled_staging]

    validates_with NoAdditionalParamsValidator

    validates :guids, array: true, allow_nil: true
    validates :names, array: true, allow_nil: true
    validates :running_space_guids, array: true, allow_nil: true
    validates :staging_space_guids, array: true, allow_nil: true
    validates :globally_enabled_running, allow_nil: true, boolean: true
    validates :globally_enabled_staging, allow_nil: true, boolean: true

    def self.from_params(params)
      super(params, %w())
    end
  end
end
