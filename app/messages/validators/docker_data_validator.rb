require 'messages/nested_message_validator'

module VCAP::CloudController
  class DockerDataValidator < NestedMessageValidator
    ALLOWED_KEYS = %i[image username password].freeze

    validates :image, string: true, presence: { message: 'required' }

    validates_with BaseMessage::NoAdditionalKeysValidator

    delegate :type, :data, to: :record

    def image
      record.try(:data).try(:fetch, :image, nil)
    end

    def should_validate?
      record.type == 'docker'
    end

    def error_key
      :data
    end

    def extra_keys
      disallowed_params = (record.try(:data) || {}).except(*allowed_keys)
      disallowed_params.keys
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
