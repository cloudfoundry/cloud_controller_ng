require 'messages/metadata_list_message'

module VCAP::CloudController
  class DeploymentsListMessage < MetadataListMessage
    register_allowed_keys [
      :app_guids,
      :states,
      :status_reasons,
      :status_values,
    ]

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates :status_reasons, array: true, allow_nil: true
    validates :status_values, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(app_guids states status_reasons status_values))
    end
  end
end
