require 'messages/list_message'

module VCAP::CloudController
  class SecurityGroupListMessage < ListMessage
    register_allowed_keys [
      :names,
      :running_space_guids,
      :staging_space_guids,
      :globally_enabled_running,
      :globally_enabled_staging
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :running_space_guids, array: true, allow_nil: true
    validates :staging_space_guids, array: true, allow_nil: true
    validates :globally_enabled_running, boolean_string: true, allow_nil: true
    validates :globally_enabled_staging, boolean_string: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names running_space_guids staging_space_guids))
    end
  end
end
