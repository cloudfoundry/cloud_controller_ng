require 'messages/metadata_list_message'

module VCAP::CloudController
  class TasksListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :states,
      :app_guids,
      :organization_guids,
      :space_guids,
      :app_guid,
      :sequence_ids,
    ]

    validates_with NoAdditionalParamsValidator # from BaseMessage

    validates :names, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }
    validate :non_app_nested_request, if: -> { !app_guid.present? }
    validates :sequence_ids, array: true, allow_nil: true

    def to_param_hash
      super(exclude: [:app_guid])
    end

    def self.from_params(params)
      super(params, %w(names states app_guids organization_guids space_guids sequence_ids))
    end

    private

    def app_nested_request
      invalid_params = []
      invalid_params << :space_guids if space_guids
      invalid_params << :organization_guids if organization_guids
      invalid_params << :app_guids if app_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_params.join("', '")}'") if invalid_params.present?
    end

    def non_app_nested_request
      invalid_params = []
      invalid_params << :sequence_ids if sequence_ids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_params.join("', '")}'") if invalid_params.present?
    end
  end
end
